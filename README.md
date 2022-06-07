<img align="right" src="bluejay.svg" alt="Bluejay" width="250">

# Bluejay

[![GitHub release (latest by date)](https://img.shields.io/github/downloads/mathiasvr/bluejay/latest/total?style=for-the-badge)](https://github.com/mathiasvr/bluejay/releases/latest)
[![Discord](https://img.shields.io/discord/811989862299336744?color=7289da&label=Discord&logo=discord&logoColor=white&style=for-the-badge)](https://discord.gg/phAmtxnMMN)

Digital ESC firmware for controlling brushless motors in multirotors.

> Based on [BLHeli_S](https://github.com/bitdump/BLHeli) revision 16.7

Bluejay aims to be an open source successor to BLHeli_S adding several improvements to ESCs with Busy Bee MCUs.

## Current Features

- Digital signal protocol: DShot 150, 300 and 600
- Bidirectional DShot: RPM telemetry
- Selectable PWM frequency: 24, 48 and 96 kHz
- PWM dithering: 11-bit effective throttle resolution
- Power configuration: Startup power and RPM protection
- High performance: Low commutation interference
- Smoother throttle to pwm conversion
- User configurable startup tunes :musical_note:
- Smooth throttle limitting based on temperature
- Watchdog timer protection
- Temperature throttle limit & notification
	- Smooth throttle limitting
	- Notify Betaflight 0 rpm when temperature limit is reached. Note. Activate OSD Motor Diagnostics in Betaflight to see it as an stuck 'S' motor.
- Numerous optimizations and bug fixes

See the project [changelog](CHANGELOG.md) for a list of changes.

## Flashing ESCs
Bluejay firmware can be flashed to BLHeli_S compatible ESCs and configured using the following configurator tools:

- [ESC Configurator](https://esc-configurator.com/) (PWA)
- [Bluejay Configurator](https://github.com/mathiasvr/bluejay-configurator/releases) (Standalone)

You can also do it manually by downloading the [release binaries](https://github.com/mathiasvr/bluejay/wiki/Release-binaries).

## Documentation
See the [wiki](https://github.com/mathiasvr/bluejay/wiki) for documentation.

## Contribute
Any help you can provide is greatly appreciated!

If you have problems, suggestions or other feedback you can open an [issue](https://github.com/mathiasvr/bluejay/issues).

You can also join our [Discord server](https://discord.gg/phAmtxnMMN) to ask questions and discuss Bluejay!

### Build

Please see the [wiki](https://github.com/mathiasvr/bluejay/wiki/Building-from-source) for instructions on how to build Bluejay from source.
