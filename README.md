  # Rotisserie Oven Digital Twin

  A PLC-based digital twin of a commercial-style chicken rotisserie oven.

  The project combines a 3D virtual plant built with **Godot** and an industrial-style control system implemented with **CODESYS Control for Raspberry Pi 64 SL** running on a **Raspberry Pi 5**.

  ## Project objective

  The objective is to create a realistic closed-loop digital twin in which:

  - **Godot** models and visualizes the virtual rotisserie oven and its thermal behaviour.
  - **CODESYS** implements PLC control logic, PID temperature regulation, cooking sequence logic, rotisserie control, and safety interlocks.
  - **Raspberry Pi 5** runs the CODESYS Control runtime.
  - **OPC UA** is planned as the communication interface between the virtual plant and the PLC controller.

  The goal is to reproduce the behaviour of a modern commercial-style rotisserie control system rather than simply animate an oven.

  ## System architecture

  ```text
                          WINDOWS PC
          +------------------------------------------+
          |                                          |
          |                GODOT                     |
          |        3D Digital Twin / Plant           |
          |                                          |
          |   Oven thermal model                    |
          |   Chicken thermal model                 |
          |   Rotisserie mechanical model           |
          |   Visualisation                         |
          +-------------------+----------------------+
                              |
                            OPC UA
                              |
                              v
                  RASPBERRY PI 5
          +------------------------------------------+
          | Raspberry Pi OS 64-bit                  |
          |                                          |
          | CODESYS Control for Raspberry Pi 64 SL  |
          |                                          |
          | PRG_Main                                |
          | FB_TemperaturePID                       |
          | FB_Heater                               |
          | FB_RotisserieMotor                     |
          | FB_CookingSequence                      |
          | FB_AlarmInterlock                       |
          +------------------------------------------+
  ```

  ### Separation of responsibilities

  **Godot = Plant**

  Godot answers:

  > What happens to the virtual oven and chicken when the controller changes the heater and rotisserie commands?

  **CODESYS = Controller**

  CODESYS answers:

  > Given the measured temperature, recipe, commands, and safety states, what should the oven do?

  **Raspberry Pi 5 = PLC runtime**

  The Pi 5 executes the CODESYS application.

  **OPC UA = Data interface**

  OPC UA is intended to expose named process variables instead of maintaining a manually assigned Modbus register map.

  ## Control philosophy

  This is **not** intended to be a 2-input/2-output MIMO PID system.

  The controls are separated into three functions.

  ### 1. Oven temperature PID

  ```text
  Oven Temperature Setpoint
            |
            v
          PID
            ^
            |
    Oven Temperature
            |
            v
      Heater Output %
  ```

  The oven/chamber temperature is the primary closed-loop process variable.

  ### 2. Rotisserie control

  Rotisserie speed is independently commanded.

  ```text
  Recipe / Operator Command
              |
              v
      Rotisserie Controller
              |
              v
        Motor / Gearbox
              |
              v
        Actual RPM
  ```

  The initial simulation may use a few RPM of spit speed. A later version can model motor acceleration, inertia, gearbox behaviour, and faults.

  ### 3. Cooking sequence

  The chicken/core temperature is primarily used to determine cooking progress and recipe transitions rather than being the second PV of a second PID loop.

  Example:

  ```text
  IDLE
    |
    v
  PREHEAT
    |
    | oven reaches setpoint
    v
  COOKING
    |
    | chicken reaches target / time condition
    v
  BROWNING
    |
    v
  COMPLETE
    |
    v
  HOLD / COOL
  ```

  ## Virtual plant model

  ### Oven thermal model

  The first-order oven model is:

  $$
  C_{th}\frac{dT_o}{dt} = P_h - K_o(T_o-T_a)
  $$

  or:

  $$
  \frac{dT_o}{dt} = \frac{P_h-K_o(T_o-T_a)}{C_{th}}
  $$

  where:

  - $T_o$ = oven/chamber temperature
  - $T_a$ = ambient temperature
  - $P_h$ = heater power
  - $C_{th}$ = effective thermal capacitance
  - $K_o$ = effective heat-loss coefficient

  The discrete simulation is:

  $$
  T_o(k+1)=T_o(k)+\frac{P_h-K_o(T_o(k)-T_a)}{C_{th}}\Delta t
  $$

  ### Chicken thermal model

  The initial chicken model is a first-order heat-transfer model:

  $$
  C_c\frac{dT_c}{dt}=K_c(T_o-T_c)
  $$

  or:

  $$
  \frac{dT_c}{dt}=\frac{K_c(T_o-T_c)}{C_c}
  $$

  This produces realistic thermal lag between the oven and the chicken core.

  A future model may use separate surface and core temperatures and may include moisture loss, radiation/convection effects, and rotation-dependent heat exposure.

  ### Rotisserie model

  The first version may represent:

  ```text
  RPM command
      |
      v
  Motor / gearbox dynamics
      |
      v
  Actual RPM
      |
      v
  Chicken rotation
  ```

  A later model can make chicken heat exposure depend on angular position and speed.

  ## Proposed CODESYS project structure

  ```text
  Application
  |
  +-- PRG_Main
  +-- GVL_Oven
  +-- FB_TemperaturePID
  +-- FB_Heater
  +-- FB_RotisserieMotor
  +-- FB_CookingSequence
  +-- FB_AlarmInterlock
  +-- Task Configuration
      |
      +-- MainTask
          |
          +-- PRG_Main
  ```

  Initial task configuration:

  - Task type: **Cyclic**
  - Interval: **100 ms**
  - Program call: **PRG_Main**

  ## Proposed process variables

  ### Measurements from Godot to CODESYS

  ```text
  Oven_Temperature
  Chicken_Temperature
  Ambient_Temperature
  Door_Closed
  Emergency_Stop
  ```

  ### Commands from CODESYS to Godot

  ```text
  Heater_Output
  Rotisserie_Run
  Rotisserie_Speed
  ```

  ### Controller settings and status

  ```text
  Oven_Setpoint
  Cooking_Active
  Cooking_Complete
  Oven_Fault
  ```

  Variable names are preferred over communication-specific register numbers.

  ## OPC UA plan

  The intended interface is:

  ```text
  CODESYS = OPC UA Server
  Godot   = OPC UA Client
  ```

  A logical namespace may eventually resemble:

  ```text
  RotisserieOven
  |
  +-- Measurements
  |   +-- OvenTemperature
  |   +-- ChickenTemperature
  |   +-- AmbientTemperature
  |
  +-- Settings
  |   +-- OvenSetpoint
  |   +-- RotisserieSpeed
  |
  +-- Commands
  |   +-- RotisserieRun
  |   +-- StartCycle
  |   +-- StopCycle
  |
  +-- Outputs
  |   +-- HeaterOutput
  |   +-- RotisserieSpeedOutput
  |
  +-- Status
      +-- DoorClosed
      +-- Fault
      +-- CookingComplete
  ```

  For development, OPC UA security and certificate handling should be configured appropriately before exposing the server beyond a trusted local network.

  ## Commercial-style rotisserie concept

  The digital twin is intended to represent a modern commercial-style rotisserie with functions such as:

  - heated cooking chamber
  - horizontal rotating spit/bar
  - independently commanded rotisserie speed
  - chamber temperature measurement
  - optional food/core temperature probe
  - cooking recipe / state sequence
  - door/interlock state
  - alarms and faults
  - browning/finishing stage
  - optional circulation fan
  - drip tray / cooking cavity details

  The exact heater arrangement, fan arrangement, rotisserie speed, motor power, and cooking recipe are treated as configurable engineering assumptions unless verified against a specific commercial oven model. The model can be extended to multiple independently controlled heater zones if required.

  ## Typical control sequence

  An initial simulated recipe may be:

  ```text
  IDLE
    Heater = 0%
    Rotisserie  = 0 RPM

  PREHEAT
    Oven SP = 180 °C
    Heater controlled by PID
    Rotisserie = 0 RPM

  COOKING
    Oven SP = 180 °C
    Heater controlled by PID
    Rotisserie = 4 RPM
    Monitor chicken temperature

  BROWNING
    Oven SP = 200 °C
    Rotisserie = 5 RPM

  COMPLETE
    Heater = 0%
    Rotisserie = 0 RPM
  ```

  These are **simulation starting points**, not specifications for a particular commercial brand or model.

  ## Safety and interlocks

  The digital twin should model PLC-style interlocks such as:

  ```text
  Door open
      -> heater disabled

  Emergency stop
      -> heater disabled
      -> rotisserie stopped

  Overtemperature
      -> heater disabled
      -> fault latched

  Motor fault
      -> rotisserie stopped

  Sensor fault
      -> safe state / alarm
  ```

  ## Development roadmap

  ### Phase 1 — Platform

  - Raspberry Pi 5
  - Raspberry Pi OS 64-bit
  - CODESYS Control for Raspberry Pi 64 SL
  - CODESYS communication and runtime test
  - cyclic PLC task

  ### Phase 2 — PLC control

  - GVL_Oven
  - FB_RotisserieMotor
  - FB_Heater
  - FB_TemperaturePID
  - FB_CookingSequence
  - FB_AlarmInterlock
  - PRG_Main

  ### Phase 3 — Godot plant

  - 3D oven
  - heater visualisation
  - rotisserie animation
  - oven thermal model
  - chicken thermal model
  - motor/gearbox model

  ### Phase 4 — OPC UA

  - publish selected CODESYS variables
  - verify using an OPC UA client
  - connect Godot to CODESYS

  ### Phase 5 — Closed-loop digital twin

  ```text
  Godot Oven Temperature
          |
          v
  CODESYS PID
          |
          v
  Heater Output
          |
          v
  Godot Thermal Model
          |
          +----------> new Oven Temperature
  ```

  Then add:

  ```text
  Godot Chicken Temperature
          |
          v
  CODESYS Cooking Sequence
          |
          v
  Recipe / Browning / Complete
  ```

  ### Phase 6 — Advanced model

  Potential extensions:

  - multiple heater zones
  - convection fan
  - radiation approximation
  - rotation-dependent heat exposure
  - door-opening disturbances
  - ambient-temperature disturbances
  - sensor noise and failure
  - actuator faults
  - PID tuning experiments
  - data logging and trend plots
  - operator recipe interface

  ## Recommended repository layout

  ```text
  rotisserie-oven-digital-twin/
  |
  +-- README.md
  +-- LICENSE
  +-- .gitignore
  |
  +-- godot/
  |   +-- project.godot
  |   +-- scenes/
  |   +-- scripts/
  |   +-- models/
  |   +-- textures/
  |   +-- ...
  |
  +-- codesys/
  |   +-- RotisserieOven_Pi5/
  |       +-- RotisserieOven_Pi5.project
  |       +-- ...
  |
  +-- docs/
  |   +-- architecture.md
  |   +-- control.md
  |   +-- thermal-model.md
  |   +-- opcua.md
  |
  +-- simulation/
      +-- ...
  ```
## Control Documentation

The detailed control specifications for the commercial‑style rotisserie are documented in the [Control Documentation](CONTROL.md). This file contains safety interlocks, CODESYS UI layout, OPC UA variable mapping, cooking sequence details, and troubleshooting guidance.


  ## Git workflow

  The Windows PC is the development machine.

  - Use **CODESYS** for PLC programming.
  - Use **Godot** for the digital twin and plant simulation.
  - Use **VS Code** for Markdown/documentation and general Git work.
  - Use **SSH** to administer the Raspberry Pi, not to manually transfer CODESYS PLC binaries.
  - Use **Git** to version the Godot project, CODESYS project, and engineering documentation.

  ## Project status

  Current target:

  - Raspberry Pi 5: PLC runtime target
  - CODESYS: Raspberry Pi 64 SL
  - PLC task: 100 ms cyclic
  - Godot: virtual rotisserie oven and dynamic plant
  - Communication: OPC UA planned

  The project is being developed incrementally so that each layer can be tested independently before closing the loop.
