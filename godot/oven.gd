extends Node3D

# =========================
# OVEN PARAMETERS
# =========================
@onready var temperature_label = $TemperatureLabel
@export var ambient_temperature: float = 25.0
@export var temperature: float = 25.0

# Maximum heater power
@export var max_heater_power: float = 2000.0

# Thermal parameters
@export var thermal_capacitance: float = 5000.0
@export var heat_loss_coefficient: float = 8.0

# Heater command: 0.0 = OFF, 1.0 = 100%
@export_range(0.0, 1.0) var heater_power: float = 1.0

@export var rotisserie_running: bool = true
@export_range(0.0, 100.0, 1.0) var rotisserie_speed_percent: float = 20.0

@onready var heater1 = $OvenBody/BackHeater1
@onready var heater2 = $OvenBody/BackHeater2
@onready var heater3 = $OvenBody/BackHeater3

@onready var heater_light1 = $OvenBody/BackHeater1/HeaterLight1
@onready var heater_light2 = $OvenBody/BackHeater2/HeaterLight2
@onready var heater_light3 = $OvenBody/BackHeater3/HeaterLight3

@onready var rotisserie_bar = $OvenBody/RotisserieBar


func _physics_process(delta):

	# -------------------------
	# HEATING
	# -------------------------
	# Heater power in watts
	var heater_watts = heater_power * max_heater_power

	# Heat lost to the environment
	var heat_loss = heat_loss_coefficient * (temperature - ambient_temperature)

	# Thermal dynamic equation
	var temperature_rate = (heater_watts - heat_loss) / thermal_capacitance

	# Integrate temperature
	temperature += temperature_rate * delta

	# Display temperature
	temperature_label.text = "Temperature: %.1f °C" % temperature
	
	# -------------------------
	# ROTISSERIE MOTOR
	# in rad/s
	# -------------------------
	if rotisserie_running:
		var speed = 1.6 * (rotisserie_speed_percent / 100.0)
		rotisserie_bar.rotate_x(speed * delta)
	
	# -------------------------
	# HEATER VISUAL
	# -------------------------
	update_heater_visual()
	
	
func update_heater_visual():

	# Heater colour
	var cold_color = Color("#4A1F0F")
	var hot_color = Color("#FF6600")

	var heater_color = cold_color.lerp(hot_color, heater_power)

	heater1.material.albedo_color = heater_color
	heater2.material.albedo_color = heater_color
	heater3.material.albedo_color = heater_color


	# Emission
	var emission_color = Color("#FF2000")

	heater1.material.emission_enabled = true
	heater2.material.emission_enabled = true
	heater3.material.emission_enabled = true

	heater1.material.emission = emission_color
	heater2.material.emission = emission_color
	heater3.material.emission = emission_color

	var emission_energy = heater_power * 5.0

	heater1.material.emission_energy_multiplier = emission_energy
	heater2.material.emission_energy_multiplier = emission_energy
	heater3.material.emission_energy_multiplier = emission_energy


	# Actual orange light
	var light_energy = heater_power * 2.0

	heater_light1.light_energy = light_energy
	heater_light2.light_energy = light_energy
	heater_light3.light_energy = light_energy
	
	
