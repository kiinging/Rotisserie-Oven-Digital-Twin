extends Node
class_name PlantInterface

## Plant <-> Controller communication interface.
##
## In production this node will speak OPC UA to a CODESYS controller. For now it
## exposes the process variables and command inputs as plain properties so the
## rest of the Godot project can be wired and tested independently.
##
## Variable names match the README / specification:
##     From controller (inputs):
##         Heater_Output_1, Heater_Output_2, Heater_Output_3   (0..100%)
##         Circulation_Fan_Run                                (bool)
##         Rotisserie_Run                                     (bool)
##         Rotisserie_Speed                                   (RPM main)
##         Start_Cycle                                        (bool, edge)
##         Stop_Cycle                                         (bool, edge)
##     To controller (measurements / status):
##         Oven_Temperature_1, Oven_Temperature_2, Oven_Temperature_3
##         Chicken_Temperature
##         Ambient_Temperature
##         Door_Closed
##         Emergency_Stop
##         Rotisserie_Actual_RPM
##         Rotisserie_Actual_Spit_RPM
##         Oven_Fault

signal heater_output_changed(heater_index: int, percent: float)
signal circulation_fan_run_changed(running: bool)
signal rotisserie_run_changed(running: bool)
signal rotisserie_speed_changed(rpm: float)
signal start_cycle_pulse()
signal stop_cycle_pulse()

# --- Commands from controller ------------------------------------------------
var heater_output_percent: Array[float] = [0.0, 0.0, 0.0]


func set_heater_output(value: Variant) -> void:
	if typeof(value) == TYPE_ARRAY:
		for i in mini(value.size(), heater_output_percent.size()):
			var v: float = clampf(float(value[i]), 0.0, 100.0)
			if v != heater_output_percent[i]:
				heater_output_percent[i] = v
				heater_output_changed.emit(i, v)
	else:
		# A single float applies to all zones.
		var v: float = clampf(float(value), 0.0, 100.0)
		for i in heater_output_percent.size():
			if v != heater_output_percent[i]:
				heater_output_percent[i] = v
				heater_output_changed.emit(i, v)

var circulation_fan_run: bool = true:
	set(value):
		if value != circulation_fan_run:
			circulation_fan_run = value
			circulation_fan_run_changed.emit(value)

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

# --- Measurements from plant -------------------------------------------------
var oven_temperature_1: float = 25.0   ## upper chamber
var oven_temperature_2: float = 25.0   ## centre chamber
var oven_temperature_3: float = 25.0   ## lower chamber
var chicken_temperature: float = 25.0
var ambient_temperature: float = 25.0
var door_closed: bool = true
var emergency_stop: bool = false
var rotisserie_actual_rpm: float = 0.0
var rotisserie_actual_spit_rpm: float = 0.0
var oven_fault: bool = false


func pulse_start_cycle() -> void:
	_start_cycle = true
	start_cycle_pulse.emit()
	_start_cycle = false


func pulse_stop_cycle() -> void:
	_stop_cycle = true
	stop_cycle_pulse.emit()
	_stop_cycle = false


func publish(oven_temp_1: float, oven_temp_2: float, oven_temp_3: float,
		chicken_temp: float, ambient: float, closed: bool, estop: bool,
		main_rpm: float, spit_rpm: float, fault: bool) -> void:
	oven_temperature_1 = oven_temp_1
	oven_temperature_2 = oven_temp_2
	oven_temperature_3 = oven_temp_3
	chicken_temperature = chicken_temp
	ambient_temperature = ambient
	door_closed = closed
	emergency_stop = estop
	rotisserie_actual_rpm = main_rpm
	rotisserie_actual_spit_rpm = spit_rpm
	oven_fault = fault
