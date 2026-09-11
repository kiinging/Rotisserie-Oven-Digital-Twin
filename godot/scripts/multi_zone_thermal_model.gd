extends Node
class_name MultiZoneThermalModel

## Three-zone thermal model of the rotisserie oven chamber.
##
## Each rear heater zone has its own temperature state. Heat transfer between
## zones is modelled with a simple convection coefficient, and a circulation
## fan increases the inter-zone coupling when it is running.
##
## Equations (discrete):
##     C_i * dT_i/dt = P_i - K_loss*(T_i - T_a) - K_zone*(T_i - T_j)  (for each i)
##
## All parameters are tunable through @export so the model can be refined later.

signal temperature_changed(zone: int, temperature: float)

@export var ambient_temperature: float = 25.0
@export var initial_temperature: float = 25.0

## Effective heater power in watts per zone at 100% command.
@export var max_heater_power_w: float = 4000.0

## Thermal capacitance per zone (J/K).
@export var thermal_capacitance: float = 12000.0

## Steady-state heat-loss coefficient per zone to ambient (W/K).
@export var heat_loss_coefficient: float = 8.0

## Additional heat loss coefficient applied while the door is open (W/K).
@export var door_open_extra_loss: float = 18.0

## Inter-zone heat transfer coefficient with fan OFF (W/K).
@export var zone_coupling_base: float = 4.0

## Inter-zone heat transfer multiplier with fan ON.
@export var zone_coupling_fan_on: float = 12.0

## Minimum chamber temperature (°C).
@export var min_temperature: float = 0.0
## Maximum chamber temperature (°C).
@export var max_temperature: float = 350.0

var temperatures: Array[float] = [25.0, 25.0, 25.0]
var heater_output: Array[float] = [0.0, 0.0, 0.0]
var door_open_factor: float = 0.0
var fan_running: bool = true


func _ready() -> void:
	for i in range(temperatures.size()):
		temperatures[i] = initial_temperature


func reset() -> void:
	for i in range(temperatures.size()):
		temperatures[i] = initial_temperature


func set_heater_output(zone: int, value: float) -> void:
	if zone >= 0 and zone < heater_output.size():
		heater_output[zone] = clampf(value, 0.0, 1.0)


func set_door_open(open: bool) -> void:
	door_open_factor = 1.0 if open else 0.0


func set_fan_running(value: bool) -> void:
	fan_running = value


func set_ambient_temperature(value: float) -> void:
	ambient_temperature = value


func step(delta: float) -> void:
	var coupling: float = zone_coupling_fan_on if fan_running else zone_coupling_base
	var loss_coeff: float = heat_loss_coefficient + door_open_factor * door_open_extra_loss

	for i in range(temperatures.size()):
		var t: float = temperatures[i]
		var heater_watts: float = heater_output[i] * max_heater_power_w
		var heat_loss: float = loss_coeff * (t - ambient_temperature)

		# Heat transfer to neighbours.
		var zone_transfer: float = 0.0
		for j in range(temperatures.size()):
			if i == j:
				continue
			zone_transfer += coupling * (temperatures[j] - t)

		var rate: float = (heater_watts - heat_loss + zone_transfer) / thermal_capacitance
		temperatures[i] = clampf(t + rate * delta, min_temperature, max_temperature)
		temperature_changed.emit(i, temperatures[i])