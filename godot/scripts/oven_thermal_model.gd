extends Node
class_name OvenThermalModel

## First-order thermal model of the rotisserie oven cooking chamber.
##
## Equations (discrete):
##     C_th * dT_o/dt = P_h - K_o * (T_o - T_a) - K_door * (T_o - T_a) * door_open_factor
##
## All parameters are tunable through @export so the model can be refined later.

signal temperature_changed(temperature: float)

@export var ambient_temperature: float = 25.0
@export var initial_temperature: float = 25.0

## Effective heater power in watts at 100% command.
@export var max_heater_power_w: float = 12000.0

## Thermal capacitance of the chamber + air + metal mass (J/K).
@export var thermal_capacitance: float = 60000.0

## Steady-state heat-loss coefficient to ambient (W/K).
@export var heat_loss_coefficient: float = 35.0

## Additional heat loss coefficient applied while the door is open (W/K).
@export var door_open_extra_loss: float = 80.0

## Minimum chamber temperature (°C).
@export var min_temperature: float = 0.0
## Maximum chamber temperature (°C).
@export var max_temperature: float = 350.0

var temperature: float = 25.0
var heater_output: float = 0.0          # 0..1
var door_open_factor: float = 0.0      # 0 = closed, 1 = open


func _ready() -> void:
	temperature = initial_temperature


func reset() -> void:
	temperature = initial_temperature


func set_heater_output(value: float) -> void:
	heater_output = clampf(value, 0.0, 1.0)


func set_door_open(open: bool) -> void:
	door_open_factor = 1.0 if open else 0.0


func set_ambient_temperature(value: float) -> void:
	ambient_temperature = value


func step(delta: float) -> void:
	var heater_watts: float = heater_output * max_heater_power_w
	var ambient_delta: float = temperature - ambient_temperature
	var loss_coefficient: float = heat_loss_coefficient + door_open_factor * door_open_extra_loss
	var heat_loss: float = loss_coefficient * ambient_delta
	var rate: float = (heater_watts - heat_loss) / thermal_capacitance
	temperature = clampf(temperature + rate * delta, min_temperature, max_temperature)
	temperature_changed.emit(temperature)