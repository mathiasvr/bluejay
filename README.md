<img align="right" src="bluejay.svg" alt="Bluejay" width="250">

# Bluejay
Digital ESC firmware for controlling brushless motors in multirotors.

> Based on [BLHeli_S](https://github.com/bitdump/BLHeli) revision 16.7

Bluejay aims to be an open source successor to BLHeli_S adding several improvements to ESCs with Busy Bee MCUs.

It is still in early development and further testing is needed before it should be used for serious flight.
If you want to help testing it any feedback you can provide is greatly appreciated!

## Current Features

- Digital signal protocol: DShot 150, 300 and 600
- Bidirectional DShot: RPM telemetry
- Selectable PWM frequency: 24, 48 and 96 kHz
- PWM dithering: 10-bit effective throttle resolution

See the project [changelog](CHANGELOG.md) for a detailed list of changes.

## Flashing ESCs
The Bluejay firmware can be flashed to BLHeli_S compatible ESCs using BLHeli Configurator.

All releases can be found in the [releases](https://github.com/mathiasvr/bluejay/releases) section.

Release files use a naming convention similar to BLHeli: `{T}_{M}_{D}_{P}_{V}.hex`.

|   |                    |                                                         |
|---|--------------------|---------------------------------------------------------|
| T | `A` - `W`          | Target ESC layout                                       |
| M | `L` or `H`         | MCU type: `L` (BB1 24MHz), `H` (BB2 48MHz)              |
| D | `0` - `90`         | Dead time (`0` *only* for ESCs with built-in dead time) |
| P | `24`, `48` or `96` | PWM frequency [kHz]                                     |
| V | eg. `0.7`          | Bluejay version                                         |
