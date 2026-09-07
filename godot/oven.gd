extends Node3D

## Rotisserie oven digital-twin — virtual plant.
##
## This script is the orchestrator. It owns the simulation tick and:
##   * drives the chamber thermal model
##   * drives the chicken thermal model
##   * drives the rotisserie mechanism (3 spits, single command)
##   * drives the door open/close animation
##   * drives heater visualisation
##   * publishes measurements through the plant interface
##
## No PLC control logic lives here. CODESYS owns PID, sequence, interlocks.

# --- Tunable engineering parameters (configurable) --------------------------
@export var ambient_temperature: float = 25.0
@export var initial_oven_temperature: float = 25.0
@export var initial_chicken_temperature: float = 5.0

@export var max_heater_power_w: float = 12000.0
@export var oven_thermal_capacitance: float = 15000.0
@export var oven_heat_loss_coefficient: float = 35.0
@export var oven_door_open_extra_loss: float = 80.0

@export var chicken_heat_transfer_coefficient: float = 12.0
@export var chicken_thermal_capacitance: float = 800.0

@export var chickens_per_spit: int = 5
@export var spit_count: int = 3
@export var nominal_cooking_rpm: float = 4.0

@export var door_open_initial: bool = false

# --- Onready scene references ----------------------------------------------
@onready var temperature_label: Label = $UI/TemperatureLabel
@onready var status_label: Label = $UI/StatusLabel

@onready var rotisserie: RotisserieMechanism = $RotisserieMechanism
@onready var door_node: OvenDoor = $OvenBody/Door/DoorPivot
@onready var thermal_model: OvenThermalModel = $OvenThermalModel
@onready var chicken_model: ChickenThermalModel = $ChickenThermalModel
@onready var heater_visual: HeaterVisual = $HeaterVisual
@onready var plant_iface: PlantInterface = $PlantInterface


func _ready() -> void:
	# Apply configurable parameters to the sub-models.
	thermal_model.ambient_temperature = ambient_temperature
	thermal_model.initial_temperature = initial_oven_temperature
	thermal_model.max_heater_power_w = max_heater_power_w
	thermal_model.thermal_capacitance = oven_thermal_capacitance
	thermal_model.heat_loss_coefficient = oven_heat_loss_coefficient
	thermal_model.door_open_extra_loss = oven_door_open_extra_loss

	chicken_model.ambient_temperature = ambient_temperature
	chicken_model.initial_temperature = initial_chicken_temperature
	chicken_model.heat_transfer_coefficient = chicken_heat_transfer_coefficient
	chicken_model.thermal_capacitance = chicken_thermal_capacitance

	rotisserie.chickens_per_spit = chickens_per_spit
	rotisserie.nominal_cooking_rpm = nominal_cooking_rpm

	door_node.set_closed(not door_open_initial)

	# Connect controller -> plant signals.
	plant_iface.heater_output_changed.connect(_on_heater_output_changed)
	plant_iface.rotisserie_run_changed.connect(_on_rotisserie_run_changed)
	plant_iface.rotisserie_speed_changed.connect(_on_rotisserie_speed_changed)

	# Default commands so the simulation does something visible at start.
	plant_iface.rotisserie_speed_rpm = nominal_cooking_rpm
	plant_iface.rotisserie_run = true
	plant_iface.heater_output_percent = 60.0


func _physics_process(delta: float) -> void:
	# 1. Door
	door_node.step(delta)

	# 2. Heater visualisation (use % from controller)
	heater_visual.set_heater_output(plant_iface.heater_output_percent / 100.0)
	heater_visual.apply()

	# 3. Thermal model
	thermal_model.set_heater_output(plant_iface.heater_output_percent / 100.0)
	thermal_model.set_door_open(not door_node.is_closed)
	thermal_model.set_ambient_temperature(ambient_temperature)
	thermal_model.step(delta)

	# 4. Chicken thermal model
	chicken_model.step(thermal_model.temperature, not door_node.is_closed, delta)

	# 5. Rotisserie mechanism
	rotisserie.set_running(plant_iface.rotisserie_run)
	rotisserie.set_commanded_rpm(plant_iface.rotisserie_speed_rpm)
	rotisserie.step(delta)

	# 6. Publish to controller side
	plant_iface.publish(
		thermal_model.temperature,
		chicken_model.temperature,
		ambient_temperature,
		door_node.is_closed,
		false,
		rotisserie.actual_rpm,
		false,
	)

	# 7. UI
	if temperature_label:
		temperature_label.text = "Oven: %.1f °C   Chicken: %.1f °C" % [
			thermal_model.temperature, chicken_model.temperature
		]
	if status_label:
		status_label.text = "Door: %s   Heater: %.0f%%   Rotisserie: %s @ %.2f RPM" % [
			"CLOSED" if door_node.is_closed else "OPEN",
			plant_iface.heater_output_percent,
			"RUN" if plant_iface.rotisserie_run else "STOP",
			rotisserie.actual_rpm,
		]


# --- Controller command handlers -------------------------------------------
func _on_heater_output_changed(_percent: float) -> void:
	# Thermal model and heater visual read the value each tick.
	pass


func _on_rotisserie_run_changed(running: bool) -> void:
	rotisserie.set_running(running)


func _on_rotisserie_speed_changed(_rpm: float) -> void:
	rotisserie.set_commanded_rpm(_rpm)