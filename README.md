## Introduction
The Assetto T-180 is a modular vehicle platform designed to replicate, and to the furthest extent reasonable, simulate the T-180 racing vehicles from the 2008 Speed Racer movie. The cars using this platform are intended for use in the vehicle simulation game Assetto Corsa with Custom Shaders Patch's physics extensions, which they rely on to a high level.

## What is a T-180?
T-180s are specialized racing vehicles that use four wheel independent steering, thrusters, active aero, and other technologies to drive and race on the purpose-built banked and looped circuits homologated by the World Racing League. While not a spec series, there is a common rule set, likely specifying things such as tire dimensions and materials, maximum power outputs, allowed and banned materials, required safety equipment, and banned offensive devices. Each team constructs their own car within the bounds of the regulations.

The cars, at minimum, feature:
- a power source that generates tractive effort at the wheels; 
- independent steering, suspension, and braking mechanisms controlling the positioning of each wheel;
- a cockpit with a steering wheel, pedals, and other controls for the drivetrain, such as a shift lever, if the car has a traditional transmission;
- integral jacks which can lift the car for maintenance or for strategic jumps during races.

As examples, cars could also feature the following technologies:
- exhaust thrusters fed from turbine engines or other pressure sources;
- active aerodynamic devices for control mid-jump or for extra downforce on less banked corners;
- torque vectoring and/or traction control through use of active differentials, electric power transmission, or other means;
- brake vectoring and/or anti-lock braking systems;
- exhaust thrust vectoring;
- active backfeed suspension to control ride height and to dampen jump landings.

The driver's controls are similar in form to that of a classical race car, but they can serve different functions depending on the construction of the car:
- The steering wheel is not directly connected to any wheel, instead serving as an input device to the car's central computer, which uses steering angle, car trajectory, car speed, and other factors to drive the steering actuators to pivot the wheels;
- The pedals may be set up traditionally (clutch, brake, gas) or non-traditionally, with as many as five pedals spotted on certain cars;
- A gear-like lever may be present, but it may or may not control a gearbox;
- Steering wheels can have many buttons on them to control the car's different modes or features, such as the jacks or the steering control modes.

## Requirements
- A legal and activated copy of Assetto Corsa for personal computers
- Custom Shaders Patch public version v0.2.6 or preview version v0.2.7p1 or higher
- Custom Shaders Patch
- Virtual Racing Cars' Extended Controls app
- Extended Controls

## Installation
The vehicles are installed to Assetto Corsa by extracting their folders contained within the downloaded zip file (available on the Releases page) to your Assetto Corsa install directory under "assettocorsa/content/cars". Installation using third-party tools or launchers may not work reliably, especially upon updating the car.

## Controls
The car makes use of special bindings for its different features. To bind these controls, load the car in-game and open the Extended Controls app. To bind a control, navigate to it in Extended Controls, click on the binding button, and press the keyboard, wheel, or gamepad button you want to bind to it. 
For cars that are equipped with a turbine engine, it is recommended to bind at least the "Turbine Throttle Override" control. This control is used often both during turns (for extra cornering force under high drift angles) and on straights (for extra acceleration). Other controls are explained in the Systems section below.

## Systems
T-180s can be equipped with a variety of systems. Below is a short explanation of the systems configured for the "T-180 Demo" car included with each release.

### Jump Jacks
The car is equipped with four jacks at each corner that can thrust the car into the air on command. They can be activated all at once or on the left or right independently.

### Engine and Drivetrain
The car uses a V-12 piston engine for its mechanical energy generation. The engine generates rotary motion by deflagrating fuel inside its combustion chambers to drive pistons. The fuel is a conventional racing gasoline mixture homologated by the WRL. The engine is mechanically linked through a driver-operated clutch to a manually-shifted six-speed gearbox and final drive, which can be reconfigured to the driver's gear ratio preferences. It is further connected through a center differential to a front differential and rear differential powering each wheel through a flexible mechanical connection.

### Integrated Turbine
A low-inertia turbojet engine is integrated with the piston engine to provide direct thrust output at the rear of the car for enhanced cornering and extra acceleration. The spool of the turbojet is geared to a torque converter attached to the main engine to allow high turbine RPMs to "drag up" the piston engine RPM if it is lower. The turbine also contains a bleed-air system which, much like a turbo- or supercharger, can deliver pressurized air to the piston engine for extra power, though the turbine must be spun up for this boost pressure to be developed. The torque converter can be disengaged to allow the turbine to spin freely from the piston engine, and the turbine can be cut off entirely during times when rearward blast thrust may be dangerous to the pit crew.

### Wheel Steering Controller
The wheels are controlled independently of each other via servo motors commanded by the car's central computer. The computer can detect each wheel's slip angle, or "angle of attack", and can steer each wheel to a specified offset of that angle. Angle offsets are calculated through an algorithm that takes the car's trajectory and the driver's steering angle as inputs. On entry to a corner and upon steering input, the wheels are steered both to change the car's trajectory and to change the chassis attack angle, or drift angle. Holding the wheel at zero steering angle will maintain a drift angle if the car is in a corner and will maintain a straight trajectory if the car is traveling straight. Countersteering will reduce the drift angle and straighten the car's trajectory.
The computer's control algorithm can also be temporarily modified via use of the "Rear Anti-Crab" and "Lock Rears" commands. "Lock Rears" will force the rear wheels to face forward like a traditional car and forbid the computer to use them to steer the car. "Rear Anti-Crab" will change the gains in the control algorithm to greatly reduce the car's chassis attack angle during a corner, which can be preferable on traditional flat tracks.

# Development

## Car Builder
The repository is organized so that the included "builder.py" script can assemble functional but unique T-180s from components located under the Source folder. Inside that folder is a subfolder "base" which contains common code and configurations that every car uses. There are then subfolders next to the base folder named with the ID of the car to be built; the folders contain all the car-specific data, such as "model.kn5" (the 3D model of the car's body), sound data, UI information and graphics, etc. Files from the car's folder will override the base files if there are conflicts to allow for editing of the base design. The code (script_*.lua) files under the "data" folder should not be edited to hardcode values for a new car; instead, the file "car_config.lua" should be edited to define the car's configuration and the base code should be edited to utilize that configuration properly.

## Cphys Controller Inputs Index
0. LF Steer Rod 1
1. LF Steer Rod 2
2. RF Steer Rod 1
3. RF Steer Rod 2
4. LR Steer Rod 1
5. LR Steer Rod 2
6. RR Steer Rod 1
7. RR Steer Rod 2
8. Turbine Throttle (remapped so that minThrottle input = 0 output)
9. Turbine Thrust (1000N = 0, 8000N = 1, lerp between and clamp at bounds)
10. Turbine RPM
11. Turbine Fuel Pump On/Off
12. Turbine Afterburner Throttle

## Custom Setup Items Index
0. FFB Gain
1. FFB Smoothing
2. FFB Front Angle Gain
3. FFB Front Slip Gain
4. FFB Rear Angle Gain
5. FFB Rear Slip Gain
6. FFB Lateral G Effect
7. SteerCtrl Drift Angle Power
8. SteerCtrl Drift Angle Damping
9. SteerCtrl Front Steering Power
10. SteerCtrl Front Steering Damping
11. SteerCtrl Rear Steering Power
12. SteerCtrl Rear Steering Damping
13. SteerCtrl Wheel Steer Power
14. SteerCtrl Front Crab Gain
15. SteerCtrl Rear Crab Gain
16. SteerCtrl Front Countersteer Gain
17. SteerCtrl Front Countersteer Limit
18. SteerCtrl Rear Countersteer Gain
19. SteerCtrl Rear Countersteer Limit


