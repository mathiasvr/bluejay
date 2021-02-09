<img align="right" src="bluejay.svg" alt="Bluejay" width="250">

# Bluejay
Digital ESC firmware for controlling brushless motors in multirotors.

> Based on [BLHeli_S](https://github.com/bitdump/BLHeli) revision 16.7

Bluejay aims to be an open source successor to BLHeli_S adding several improvements to ESCs with Busy Bee MCUs.

## Current Features

- Digital signal protocol: DShot 150, 300 and 600
- Bidirectional DShot: RPM telemetry
- Selectable PWM frequency: 24, 48 and 96 kHz
- PWM dithering: 11-bit effective throttle resolution

See the project [changelog](CHANGELOG.md) for a detailed list of changes.

## Flashing ESCs
Bluejay firmware can be flashed to BLHeli_S compatible ESCs and configured using [Bluejay Configurator](https://github.com/mathiasvr/blheli-configurator/releases) (a fork of BLHeli Configurator).

### Release binaries

All releases can be found in the [releases](https://github.com/mathiasvr/bluejay/releases) section.

Release files use a naming convention similar to BLHeli: `{T}_{M}_{D}_{P}_{V}.hex`.

|   |                    |                                                         |
|---|--------------------|---------------------------------------------------------|
| T | `A` - `W`          | Target ESC layout                                       |
| M | `L` or `H`         | MCU type: `L` (BB1 24MHz), `H` (BB2 48MHz)              |
| D | `0` - `90`         | Dead time (`0` *only* for ESCs with built-in dead time) |
| P | `24`, `48` or `96` | PWM frequency [kHz]                                     |
| V | E.g. `0.7`         | Bluejay version                                         |

## Comparison of BLHeli_S and Bluejay settings
The following table shows a correspondence between BLHeli_S and Bluejay's startup power settings.

| BLHeli_S      | Bluejay            |                    |                    |
|---------------|--------------------|--------------------|--------------------|
| Startup Power | Min. Startup Power | Max. Startup Power | RPM Power (Rampup) |
| 0.031         |   2 (1001)         |  1 (1004)          |  2x                |
| 0.047         |   4 (1002)         |  2 (1008)          |  2x                |
| 0.063         |   6 (1003)         |  3 (1012)          |  3x                |
| 0.094         |   8 (1004)         |  4 (1016)          |  4x                |
| 0.125         |  12 (1006)         |  6 (1024)          |  5x                |
| 0.188         |  18 (1009)         |  9 (1035)          |  6x                |
| 0.25          |  24 (1012)         | 12 (1047)          |  7x                |
| 0.38          |  36 (1018)         | 18 (1071)          |  8x                |
| 0.50          |  50 (1024)         | 25 (1098)          |  9x                |
| 0.75          |  74 (1036)         | 37 (1145)          | 10x                |
| 1.00          | 100 (1049)         | 50 (1196)          | 11x                |
| 1.25          | 124 (1061)         | 62 (1243)          | 12x                |
| 1.50          | 150 (1073)         | 75 (1294)          | 13x                |

- **Minimum startup power:** Minimum power when starting motors. Increase if motors are not able to start with low throttle input.
- **Maximum startup power:** Limits power when starting motors or reversing direction.
- **RPM Power Protection (Rampup):** Limits how fast power can be increased. Lower values will avoid power spikes but can also decrease acceleration.

## Contribute
Any help you can provide is greatly appreciated!

If you have problems, suggestions or other feedback you can open an [issue](https://github.com/mathiasvr/bluejay/issues).
