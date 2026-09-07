extends Node
class_name ChickenThermalModel

## First-order chicken/core thermal model.
##
## Equation (discrete):
##     C_c * dT_c/dt = K_c * (T_o - T_c)
##
## This is intentionally a single representative model. The 15 visual chickens
## share this process variable. Individual chicken models can be added later by
## instantiating multiple ChickenThermalModel nodes.

signal temperature_changed(temperature: float)

@export var ambient_temperature: float = 25.0
@export var initial_temperature: float = 5.0

## Heat transfer coefficient between oven air and chicken (W/K).
@export var heat_transfer_coefficient: float = 12.0

## Effective thermal capacitance of the chicken core (J/K).
@export var thermal_capacitance: float = 800.0

## Heat transfer coefficient drop while the door is open (0..1 fraction kept).
@export var door_open_factor: float = 0.4

@export var min_temperature: float = 0.0
@export var max_temperature: float = 110.0

var temperature: float = 5.0


func _ready() -> void:
	temperature = initial_temperature


func reset() -> void:
	temperature = initial_temperature


func step(oven_temperature: float, door_open: bool, delta: float) -> void:
	var k_eff: float = heat_transfer_coefficient
	if door_open:
		k_eff *= door_open_factor
	var delta_t: float = oven_temperature - temperature
	var rate: float = (k_eff * delta_t) / thermal_capacitance
	temperature = clampf(temperature + rate * delta, min_temperature, max_temperature)
	temperature_changed.emit(temperature)