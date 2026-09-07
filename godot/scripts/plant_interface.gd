extends Node
class_name PlantInterface

## Plant <-> Controller communication interface.
##
## In production this node will speak OPC UA to a CODESYS controller. For now it
## exposes the process variables and command inputs as plain properties so the
## rest of the Godot project can be wired and tested independently.
##
## Variable names match the README:
##     From controller (inputs):
##         Heater_Output       (0..100%)
##         Rotisserie_Run      (bool)
##         Rotisserie_Speed    (RPM)
##         Start_Cycle         (bool, edge)
##         Stop_Cycle          (bool, edge)
##     To controller (measurements / status):
##         Oven_Temperature    (°C)
##         Chicken_Temperature (°C)
##         Ambient_Temperature (°C)
##         Door_Closed         (bool)
##         Emergency_Stop      (bool)
##         Rotisserie_Actual_RPM (RPM)
##         Oven_Fault          (bool)

signal heater_output_changed(percent: float)
signal rotisserie_run_changed(running: bool)
signal rotisserie_speed_changed(rpm: float)
signal start_cycle_pulse()
signal stop_cycle_pulse()

# --- Commands from controller (0..100 for Heater_Output) -------------------
var heater_output_percent: float = 0.0:
	set(value):
		var v: float = clampf(value, 0.0, 100.0)
		if v != heater_output_percent:
			heater_output_percent = v
			heater_output_changed.emit(v)

var rotisserie_run: bool = true:
	set(value):
		if value != rotisserie_run:
			rotisserie_run = value
			rotisserie_run_changed.emit(value)

var rotisserie_speed_rpm: float = 0.0:
	set(value):
		var v: float = maxf(0.0, value)
		if v != rotisserie_speed_rpm:
			rotisserie_speed_rpm = v
			rotisserie_speed_changed.emit(v)

var _start_cycle: bool = false
var _stop_cycle: bool = false

# --- Measurements from plant -----------------------------------------------
var oven_temperature: float = 25.0
var chicken_temperature: float = 25.0
var ambient_temperature: float = 25.0
var door_closed: bool = true
var emergency_stop: bool = false
var rotisserie_actual_rpm: float = 0.0
var oven_fault: bool = false


func pulse_start_cycle() -> void:
	_start_cycle = true
	start_cycle_pulse.emit()
	_start_cycle = false


func pulse_stop_cycle() -> void:
	_stop_cycle = true
	stop_cycle_pulse.emit()
	_stop_cycle = false


func publish(oven_temp: float, chicken_temp: float, ambient: float,
		closed: bool, estop: bool, actual_rpm: float, fault: bool) -> void:
	oven_temperature = oven_temp
	chicken_temperature = chicken_temp
	ambient_temperature = ambient
	door_closed = closed
	emergency_stop = estop
	rotisserie_actual_rpm = actual_rpm
	oven_fault = fault