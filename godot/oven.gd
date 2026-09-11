extends Node3D

## Rotisserie oven digital-twin — virtual plant.
##
## This script is the orchestrator. It owns the simulation tick and:
##   * drives the three-zone chamber thermal model
##   * drives the chicken thermal model
##   * drives the dual-rotation rotisserie mechanism (3 spits, single command)
##   * drives the door open/close animation
##   * drives heater visualisation
##   * drives the circulation fan
##   * publishes measurements through the plant interface
##
## No PLC control logic lives here. CODESYS owns PID, sequence, interlocks.

# --- Tunable engineering parameters (configurable) --------------------------
@export var ambient_temperature: float = 25.0
@export var initial_oven_temperature: float = 25.0
@export var initial_chicken_temperature: float = 5.0

@export var max_heater_power_w: float = 4000.0
@export var oven_thermal_capacitance: float = 12000.0
@export var oven_heat_loss_coefficient: float = 8.0
@export var oven_door_open_extra_loss: float = 18.0
@export var zone_coupling_base: float = 4.0
@export var zone_coupling_fan_on: float = 12.0

@export var chicken_heat_transfer_coefficient: float = 12.0
@export var chicken_thermal_capacitance: float = 800.0

@export var chickens_per_spit: int = 3
@export var spit_count: int = 4
@export var nominal_main_rpm: float = 2.0
@export var gear_ratio: float = 5.0

@export var door_open_initial: bool = false

# --- Onready scene references ----------------------------------------------
@onready var temperature_label: Label = $UI/TemperatureLabel
@onready var status_label: Label = $UI/StatusLabel

@onready var rotisserie: DualRotisserieMechanism = $RotisserieMechanism
@onready var door_node: OvenDoor = $OvenBody/Door/DoorPivot
@onready var thermal_model: OvenThermalModel = $OvenThermalModel
@onready var zone_model: MultiZoneThermalModel = $MultiZoneThermalModel
@onready var chicken_model: ChickenThermalModel = $ChickenThermalModel
@onready var heater_visual: HeaterVisual = $HeaterVisual
@onready var fan_node: CirculationFan = $CirculationFan
@onready var plant_iface: PlantInterface = $PlantInterface


func _ready() -> void:
	# Apply configurable parameters to the sub-models.
	thermal_model.ambient_temperature = ambient_temperature
	thermal_model.initial_temperature = initial_oven_temperature
	thermal_model.max_heater_power_w = max_heater_power_w
	thermal_model.thermal_capacitance = oven_thermal_capacitance
	thermal_model.heat_loss_coefficient = oven_heat_loss_coefficient
	thermal_model.door_open_extra_loss = oven_door_open_extra_loss

	zone_model.ambient_temperature = ambient_temperature
	zone_model.initial_temperature = initial_oven_temperature
	zone_model.max_heater_power_w = max_heater_power_w
	zone_model.thermal_capacitance = oven_thermal_capacitance
	zone_model.heat_loss_coefficient = oven_heat_loss_coefficient
	zone_model.door_open_extra_loss = oven_door_open_extra_loss
	zone_model.zone_coupling_base = zone_coupling_base
	zone_model.zone_coupling_fan_on = zone_coupling_fan_on

	chicken_model.ambient_temperature = ambient_temperature
	chicken_model.initial_temperature = initial_chicken_temperature
	chicken_model.heat_transfer_coefficient = chicken_heat_transfer_coefficient
	chicken_model.thermal_capacitance = chicken_thermal_capacitance

	rotisserie.chickens_per_spit = chickens_per_spit
	rotisserie.gear_ratio = gear_ratio
	rotisserie.nominal_main_rpm = nominal_main_rpm

	door_node.set_closed(not door_open_initial)

	# Connect controller -> plant signals.
	plant_iface.heater_output_changed.connect(_on_heater_output_changed)
	plant_iface.rotisserie_run_changed.connect(_on_rotisserie_run_changed)
	plant_iface.rotisserie_speed_changed.connect(_on_rotisserie_speed_changed)
	plant_iface.circulation_fan_run_changed.connect(_on_fan_run_changed)

	# Default commands so the simulation does something visible at start.
	plant_iface.rotisserie_speed_rpm = nominal_main_rpm
	plant_iface.rotisserie_run = true
	plant_iface.circulation_fan_run = true
	plant_iface.set_heater_output([40.0, 40.0, 40.0])


func _physics_process(delta: float) -> void:
	# 1. Door
	door_node.step(delta)
	var door_open: bool = not door_node.is_closed

	# 2. Heater visualisation (use % from controller)
	for i in range(3):
		heater_visual.set_heater_output(plant_iface.heater_output_percent[i] / 100.0)
	heater_visual.apply()

	# 3. Three-zone thermal model
	for i in range(3):
		zone_model.set_heater_output(i, plant_iface.heater_output_percent[i] / 100.0)
	zone_model.set_door_open(door_open)
	zone_model.set_fan_running(plant_iface.circulation_fan_run)
	zone_model.set_ambient_temperature(ambient_temperature)
	zone_model.step(delta)

	# 4. Chicken thermal model (use the mean of the three zones as oven air)
	var oven_mean: float = (zone_model.temperatures[0] + zone_model.temperatures[1] + zone_model.temperatures[2]) / 3.0
	chicken_model.step(oven_mean, door_open, delta)

	# 5. Circulation fan
	fan_node.set_running(plant_iface.circulation_fan_run)
	fan_node.step(delta)

	# 6. Rotisserie mechanism
	rotisserie.set_running(plant_iface.rotisserie_run)
	rotisserie.set_commanded_main_rpm(plant_iface.rotisserie_speed_rpm)
	rotisserie.step(delta)

	# 7. Publish to controller side
	plant_iface.publish(
		zone_model.temperatures[0],
		zone_model.temperatures[1],
		zone_model.temperatures[2],
		chicken_model.temperature,
		ambient_temperature,
		door_node.is_closed,
		false,
		rotisserie.actual_main_rpm,
		rotisserie.actual_spit_rpm,
		false
	)

	# 8. UI
	if temperature_label:
		temperature_label.text = "Oven T1: %.0f T2: %.0f T3: %.0f °C   Chicken: %.1f °C" % [
			zone_model.temperatures[0], zone_model.temperatures[1],
			zone_model.temperatures[2], chicken_model.temperature
		]
	if status_label:
		status_label.text = "Door: %s   Heater: %.0f%%   Fan: %s   Rotisserie: %s @ %.2f / %.2f RPM" % [
			"CLOSED" if door_node.is_closed else "OPEN",
			(plant_iface.heater_output_percent[0] + plant_iface.heater_output_percent[1] + plant_iface.heater_output_percent[2]) / 3.0,
			"RUN" if plant_iface.circulation_fan_run else "STOP",
			"RUN" if plant_iface.rotisserie_run else "STOP",
			rotisserie.actual_main_rpm,
			rotisserie.actual_spit_rpm,
		]


# --- Controller command handlers -------------------------------------------
func _on_heater_output_changed(_heater_index: int, _percent: float) -> void:
	# Thermal model and heater visual read the value each tick.
	pass


func _on_rotisserie_run_changed(running: bool) -> void:
	rotisserie.set_running(running)


func _on_rotisserie_speed_changed(_rpm: float) -> void:
	rotisserie.set_commanded_main_rpm(_rpm)


func _on_fan_run_changed(running: bool) -> void:
	fan_node.set_running(running)
