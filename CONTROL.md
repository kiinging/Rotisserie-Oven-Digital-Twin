# CONTROL.md

## 1. Introduction
This document defines the **control architecture** for the advanced commercial‑style chicken rotisserie (inspired by a Kenny Roger roaster) that is simulated in the **Rotisserie Oven Digital Twin** project. It describes the sensors, PLC implementation in **CODESYS** on a **Raspberry Pi 5**, the safety interlocks, the cooking sequence, and the OPC UA interface that connects the PLC to the **Godot 4.7.1** digital twin.

---

## 2. Sensors (Measurements from the physical plant / digital twin)
| # | Sensor | OPC UA Variable | Description |
|---|--------|----------------|-------------|
| 1 | Upper chamber temperature | `Measurements/UpperTemp` | Air temperature near the top of the oven (°C). |
| 2 | Centre chamber temperature | `Measurements/CentreTemp` | Core air temperature where the chickens rotate (°C). |
| 3 | Lower chamber temperature | `Measurements/LowerTemp` | Temperature near the bottom of the oven (°C). |
| 4 | Chicken core temperature | `Measurements/ChickenTemp` | Simulated core temperature of each chicken (°C). |
| 5 | Door status | `Measurements/DoorClosed` (BOOL) | `TRUE` when the oven door is closed. |
| 6 | Emergency stop | `Measurements/EmergencyStop` (BOOL) | External E‑Stop line – forces the system to a safe state. |
| 7 | Ambient temperature | `Measurements/AmbientTemp` | Room temperature (°C) – used as a boundary condition for the thermal model. |

---

## 3. Control System Overview
- **Hardware**: Raspberry Pi 5 running **Raspberry Pi OS 64‑bit**.
- **Runtime**: **CODESYS Control for Raspberry Pi 64 SL** (PLC runtime).
- **Main program**: `PRG_Main` orchestrates the logic.
- **Function Blocks** (implemented in CODESYS):
  - `FB_TemperaturePID` – PID controller for the oven temperature.
  - `FB_HeaterZone` – Switches heater power to the selected zone(s).
  - `FB_RotisserieMotor` – Drives the motor, handles acceleration/deceleration.
  - `FB_FanControl` – Turns the circulation fan on/off (speed fixed for now).
  - `FB_CookingSequence` – State machine that implements the recipe.
  - `FB_SafetyInterlock` – Monitors door, E‑Stop, over‑temperature, and faults.

---

## 4. PID Temperature Control
| Variable | Type | Direction | Description |
|----------|------|-----------|-------------|
| `OvenSetpoint` | REAL | Input | Desired chamber temperature (°C). |
| `HeaterOutput` | REAL | Output | PID output, 0 %–100 % duty cycle sent to the heater zone. |
| `Kp`, `Ki`, `Kd` | REAL | Config | PID tuning parameters (exposed as globals). |
| `ActualTemp` | REAL | Input | Typically the **CentreTemp** measurement. |

**Implementation notes**
- The PID runs at the **100 ms cyclic task**.
- Anti‑windup is enabled; the output is clamped to `[0, 100]`.
- The controller is disabled when any safety interlock is active; `HeaterOutput` is forced to `0`.

---

## 5. Motor Control (Rotisserie)
| Variable | Type | Direction | Description |
|----------|------|-----------|-------------|
| `RotisserieRun` | BOOL | Input | `TRUE` → motor enabled. |
| `RotisserieSpeedCmd` | REAL | Input | Desired speed in RPM (0‑10). |
| `ActualRPM` | REAL | Output | Feedback from the simulated motor (Godot). |
| `MotorFault` | BOOL | Output | Set by `FB_RotisserieMotor` when a simulated fault occurs. |

**Key behaviours**
- Motor acceleration is modelled as a first‑order ramp (configurable `RampTime`).
- When `RotisserieRun` is cleared, the motor decelerates to zero before the output is disabled.
- A fault forces `RotisserieRun` to `FALSE` and raises `MotorFault`.

---

## 6. Heater‑Zone Control
The oven is modelled with a **single heating zone** for now, but the architecture supports **multiple zones**.
- `ZoneSelect` (UINT) – selects the active zone (future extension).  
- `ZonePower` (REAL) – percentage of full power for the selected zone.
- The zone output is directly driven by `HeaterOutput` from the PID.

---

## 7. Fan Control
| Variable | Type | Direction | Description |
|----------|------|-----------|-------------|
| `FanRun` | BOOL | Input | Turns the circulation fan on/off. |
| `FanSpeed` | REAL | Input (optional) | Fixed speed percentage – not used in the current model. |
| `FanStatus` | BOOL | Output | Mirrors `FanRun` (for diagnostics). |

The fan does **not** affect the temperature PID; it only improves visual airflow in the digital twin.

---

## 8. Safety Interlocks
The PLC must place the plant in a **safe state** whenever any of the following conditions are true:
1. **Door open** – `DoorClosed = FALSE`
2. **Emergency stop** – `EmergencyStop = TRUE`
3. **Over‑temperature** – any chamber temperature exceeds `OVER_TEMP_LIMIT` (default 230 °C).
4. **Motor fault** – `MotorFault = TRUE`
5. **Sensor fault** – any temperature measurement is `NaN` or outside plausible range.

**Safe‑state actions**
- `HeaterOutput = 0`
- `RotisserieRun = FALSE`
- `FanRun = FALSE`
- Set a global `SystemFault` flag and latch it until the operator clears the fault.

---

## 9. Cooking Sequence (State Machine)
The `FB_CookingSequence` implements the classic commercial rotisserie recipe.

```
IDLE → PREHEAT → COOKING → BROWNING → COMPLETE → HOLD
```

| State | Entry actions | Exit conditions |
|-------|---------------|-----------------|
| **IDLE** | All outputs off. | Operator presses **Start Cycle**. |
| **PREHEAT** | Set `OvenSetpoint` to pre‑heat temperature (e.g., 180 °C). Heater PID active, rotisserie stopped. | Chamber temperature reaches setpoint (±1 °C). |
| **COOKING** | `RotisserieRun = TRUE`; `RotisserieSpeedCmd` set to cooking RPM (e.g., 4 RPM). | Chicken core temperature reaches target **OR** timer expires. |
| **BROWNING** | Increase `OvenSetpoint` (e.g., 200 °C) and optional higher `RotisserieSpeedCmd` (5 RPM). | Chicken core temperature reaches browning target **OR** timer expires. |
| **COMPLETE** | All outputs off, alarm/alarm‑clear. | Operator acknowledges completion. |
| **HOLD** | Maintain temperature or allow cooling, door may be opened. | Operator resets to **IDLE**. |
```

All state transitions respect the safety interlocks – any fault immediately forces the system back to **IDLE** and raises `SystemFault`.

---

## 10. OPC UA Variable Map (CODESYS ↔ Godot)
The PLC acts as an **OPC UA Server**; the Godot digital twin runs an **OPC UA Client**.

### 10.1 Measurements (read‑only for the client)
```
RotisserieOven/Measurements/UpperTemp          (REAL)
RotisserieOven/Measurements/CentreTemp         (REAL)
RotisserieOven/Measurements/LowerTemp          (REAL)
RotisserieOven/Measurements/ChickenTemp        (REAL)
RotisserieOven/Measurements/DoorClosed         (BOOL)
RotisserieOven/Measurements/EmergencyStop      (BOOL)
RotisserieOven/Measurements/AmbientTemp        (REAL)
```

### 10.2 Commands (write‑only for the client)
```
RotisserieOven/Commands/HeaterOutput            (REAL 0‑100)
RotisserieOven/Commands/RotisserieRun           (BOOL)
RotisserieOven/Commands/RotisserieSpeedCmd      (REAL RPM)
RotisserieOven/Commands/FanRun                  (BOOL)
RotisserieOven/Commands/StartCycle              (BOOL)   // edge‑triggered
RotisserieOven/Commands/StopCycle               (BOOL)   // edge‑triggered
```

### 10.3 Settings (read/write by operator via HMI)
```
RotisserieOven/Settings/OvenSetpoint            (REAL °C)
RotisserieOven/Settings/PreheatTemp             (REAL °C)
RotisserieOven/Settings/CookingTempTarget       (REAL °C)
RotisserieOven/Settings/BrowningTempTarget      (REAL °C)
RotisserieOven/Settings/CookingRPM              (REAL RPM)
RotisserieOven/Settings/BrowningRPM             (REAL RPM)
RotisserieOven/Settings/OverTempLimit           (REAL °C)
```

### 10.4 Status & Diagnostics (read‑only for the client)
```
RotisserieOven/Status/ActualRPM                (REAL RPM)
RotisserieOven/Status/SystemFault              (BOOL)
RotisserieOven/Status/MotorFault               (BOOL)
RotisserieOven/Status/CurrentState             (STRING)   // IDLE, PREHEAT, …
```

---

## 11. Integration with the Digital Twin (Godot 4.7.1)
1. **Visualization** – Godot renders the oven, rotating carousel, chickens, heater glow, fan airflow particles, and temperature colour maps.
2. **Data exchange** – The Godot client subscribes to the OPC UA variables listed above; it publishes the measured temperatures and status flags, while it writes the command variables.
3. **Synchronization** – The Godot scene runs at 60 fps; OPC UA updates occur every PLC cycle (100 ms). Interpolation is used to keep the animation smooth.
4. **Extensibility** – New zones, additional sensors, or a variable‑speed fan can be added by extending the OPC UA namespace and updating the corresponding Godot scripts.

---

## 12. Development & Testing Checklist
- [ ] Verify OPC UA connection (CODESYS server reachable from Godot).  
- [ ] Test each safety interlock individually (door open, E‑Stop, over‑temp).  
- [ ] Run the full cooking sequence and confirm correct state transitions.  
- [ ] Tune PID parameters (`Kp`, `Ki`, `Kd`) to achieve <5 s rise time and <1 °C steady‑state error.  
- [ ] Validate motor acceleration model matches expected RPM ramp (e.g., 0 → 5 RPM in 2 s).  
- [ ] Confirm that the digital twin visualizations reflect the PLC state in real time (heater glowing, fan particles, carousel rotation).  
- [ ] Document any additional variables added during later phases (multiple heater zones, variable fan speed).  

---

## 13. References
- **CODESYS Help** – *Function Block FB_TemperaturePID* documentation.  
- **OPC UA Specification** – Part 4: Services.  
- **Godot 4.7.1 Docs** – *Networking – OPC UA client example* (custom implementation).  
- **Kenny Roger Roaster** – public brochures for commercial rotisserie specifications (used as a conceptual baseline).

---

*End of CONTROL.md*
