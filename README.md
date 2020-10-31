<img align="right" src="bluejay.svg" alt="Bluejay" width="250">

# Bluejay
Digital ESC firmware for controlling brushless motors in multirotors.

A fork of [BLHeli_S](https://github.com/bitdump/BLHeli) based on revision 16.7.

## Summary
Bluejay aims to be an open source successor to BLHeli_S bringing DShot RPM telemetry to ESCs with Busy Bee MCUs.

Compared to BLHeli_S this project only supports the DShot protocol and all analog protocols have been removed to ease code maintenance.

A more detailed list of changes can be seen in the project [changelog](CHANGELOG.md).

## Project State
Bluejay is still in early development and further testing is needed before it can be used for real flight.

**Current Features:**

- Digital signal protocol: DShot 300 and 600
- Bidirectional DShot: RPM telemetry
- Selectable PWM frequency: 24 and 48 kHz

## Flashing ESCs
The Bluejay firmware can be flashed to BLHeli_S compatible ESCs using BLHeli Configurator.

All releases can be found in the [releases](https://github.com/mathiasvr/Bluejay/releases) section.

Files currently use similar naming convention to BLHeli: `{T}_{M}_{DT}_{P}_{V}.hex`.

- T: Target layout (`A` - `W`)
- M: MCU type, `L` for BB1 (24MHz), `H` for BB2 (48MHz)
- DT: Deadtime (aka Feton_Delay)
- P: PWM frequency `24` or `48`
- V: Bluejay version eg. `0.3.0`.
