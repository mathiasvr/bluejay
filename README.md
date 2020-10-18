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

A couple of important features that is planned to be implemented:

- [ ] Reduce telemetry commutation interference
- [ ] Add support for 48KHz PWM


## Flashing ESCs
The Bluejay firmware can be flashed to BLHeli_S compatible ESCs using BLHeli Configurator.
