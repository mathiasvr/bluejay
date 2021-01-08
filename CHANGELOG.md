# Changelog

All notable changes to this project will be documented in this file.

## [0.6](https://github.com/mathiasvr/bluejay/compare/v0.5...v0.6) (2021-01-08)


### Bug Fixes

* Adjust duration of lost signal beacon delay ([bf3b8e9](https://github.com/mathiasvr/bluejay/commit/bf3b8e90cbe3c7d899e52e522ef18fcedc4a71b7))
* Correct duration of beep tone 5 ([944d3fd](https://github.com/mathiasvr/bluejay/commit/944d3fd2c0430d9d76d4141c3356eb7255a136eb))
* Do not reset telemetry flag on motor start ([c54412c](https://github.com/mathiasvr/bluejay/commit/c54412c7f30be978d562e8cbcf1232174603ac32))
* Enable timer 0 interrupt vector on BB1 MCUs ([7c0b18f](https://github.com/mathiasvr/bluejay/commit/7c0b18f61724d1e3dbd462e479b63d036d8d87e6))
* Wait for FC to initialize during startup ([ec73e39](https://github.com/mathiasvr/bluejay/commit/ec73e39dfe147b44d8aea863be6beae2d30b1782))

## [0.5](https://github.com/mathiasvr/bluejay/compare/v0.4.0...v0.5) (2021-01-04)


### Features

* Rework beeper routines and add a 5th beacon tone ([5659d3b](https://github.com/mathiasvr/bluejay/commit/5659d3b9201a72d3696b3cb7d03ccaa705bbe8fc))


### Bug Fixes

* Rework startup boost, increase max number of stalls ([a23e3a1](https://github.com/mathiasvr/bluejay/commit/a23e3a12cf8388f6b6e598452fc221f1170f6758))
* Scale telemetry timings for 24MHz mode ([97d9cdc](https://github.com/mathiasvr/bluejay/commit/97d9cdc459d2cc322f4ff509b7aac7c3cbfbeda7))


### Performance Improvements

* Micro-optimize calc new wait times ([e2bc285](https://github.com/mathiasvr/bluejay/commit/e2bc285dc447cc2eb00f82ff551d6159144543c9))
* Optimize decoding of bidirectional power ([636436e](https://github.com/mathiasvr/bluejay/commit/636436e408942fe15ee3c1b1634636541e3e2eb9))
* Optimize startup boost handling ([ab829ed](https://github.com/mathiasvr/bluejay/commit/ab829ed15763226a4c7988a06a3b73735b198ee4))
* Optimize telemetry packet generation and reduce commutation interference ([b3b8560](https://github.com/mathiasvr/bluejay/commit/b3b8560dd5ed0e8d21de688de638183efdb63645))

## [0.4.0](https://github.com/mathiasvr/bluejay/compare/v0.3.0...v0.4.0) (2020-11-07)


### Features

* Add 10-bit dithering ([240d307](https://github.com/mathiasvr/bluejay/commit/240d3078fdbbb3f8e6a538c4a1d9bae713dcbd03))
* Add 96kHz pwm for 48MHz mcus ([8818252](https://github.com/mathiasvr/bluejay/commit/8818252485af2939bfc4339f6983537afac95923))


### Performance Improvements

* Optimize pwm scaling ([9eebccb](https://github.com/mathiasvr/bluejay/commit/9eebccb3f3e15141da84f2e71e744f6a22eb4e2f))
* Optimize timer 2 interrupt ([70829f9](https://github.com/mathiasvr/bluejay/commit/70829f97beef91d1dd8507ac06c922cb19813d6e))

## [0.3.0](https://github.com/mathiasvr/bluejay/compare/v0.2.1...v0.3.0) (2020-10-31)


### Features

* Add 48kHz pwm option ([01642d7](https://github.com/mathiasvr/bluejay/commit/01642d718a83105b1fb22a8b12fdf5a125f5c110))


### Bug Fixes

* Fix telemetry data conversion bug ([8e56a2a](https://github.com/mathiasvr/bluejay/commit/8e56a2a3772f94acbaef8d0237dbc114ae72b14f))
* Update telemetry start delay ([596d3be](https://github.com/mathiasvr/bluejay/commit/596d3bee2c698d775a090cf670c4d3ab69009934))


### Performance Improvements

* Micro-optimize telemetry packet creation ([c9640f9](https://github.com/mathiasvr/bluejay/commit/c9640f9e5ae6dc4f11ec2650603d30b37596ee38))

### [0.2.1](https://github.com/mathiasvr/bluejay/compare/v0.2.0...v0.2.1) (2020-10-25)


### Bug Fixes

* Reduce telemetry commutation interference ([9e95239](https://github.com/mathiasvr/bluejay/commit/9e95239c4a99694a6923d3ddf24dd99d2e47dcda))


### Performance Improvements

* Optimize some jumps ([a23c3b8](https://github.com/mathiasvr/bluejay/commit/a23c3b8372bc3022ba1f00490c198a8fc85b35af))
* Remove adc conversion call ([1d69c07](https://github.com/mathiasvr/bluejay/commit/1d69c071f74ed4459f83c6a462ef812f94e23775))
* Remove redundant instruction in telemetry code ([753bb73](https://github.com/mathiasvr/bluejay/commit/753bb73f80c428d434a459f9397914aea385906c))
* Remove rendundant jumps ([9bd8ffe](https://github.com/mathiasvr/bluejay/commit/9bd8ffe6cc40b5539dfe73a7b9ef6681b6e62c43))

## [0.2.0](https://github.com/mathiasvr/bluejay/compare/v0.1.0...v0.2.0) (2020-10-21)
First version with **Bluejay** as project name.


### ⚠ BREAKING CHANGES

* Remove legacy (non-DShot) protocols

### Bug Fixes

* Clear DShot cmd on pulse outside range ([2030235](https://github.com/mathiasvr/bluejay/commit/2030235ea7b7a69db24ed2c33ddf96a7adae7fed))
* Correct DShot 12-bit encoding ([a4f706e](https://github.com/mathiasvr/bluejay/commit/a4f706e3a6e45409d78c30a51a2bf816a61b58f7))
* Reset commutation period on idle ([d805fb6](https://github.com/mathiasvr/bluejay/commit/d805fb6ee1a6dd9fa58e7f996d5ed0a724cba7f0))


### Performance Improvements

* Micro-optimize RCP limit check ([1d7dcef](https://github.com/mathiasvr/bluejay/commit/1d7dcef3d9b1bae2660935fc18114c412a1593c8))
* Optimize a few zero checks ([40fe9e9](https://github.com/mathiasvr/bluejay/commit/40fe9e9e7395f80868ec35550f1c34e12f08e725))
* Optimize adjust_timing_two_steps routine ([a9ca295](https://github.com/mathiasvr/bluejay/commit/a9ca2957a3d2743580d9d85222ca2e5caf08923d))
* Optimize comp read jumps ([703d70a](https://github.com/mathiasvr/bluejay/commit/703d70acfd8b2f520600da151b8163ca2b5d40ed))
* Optimize new_rcp stop check ([6300e84](https://github.com/mathiasvr/bluejay/commit/6300e84999b1c86f4a681068dc3f295293d681a2))
* Remove a few unnecessary instructions ([44ff551](https://github.com/mathiasvr/bluejay/commit/44ff551a1f1e955a7a5650f76985d11c02770fdc))
* Remove double jumps ([8d19ac1](https://github.com/mathiasvr/bluejay/commit/8d19ac133839503ea2fcc6693d4f21045c8703d6))
* Simplify demag update check ([23df751](https://github.com/mathiasvr/bluejay/commit/23df7513b0c60633082c23be97e8b8e909b1a0c8))


### Code Refactoring

* Remove legacy (non-DShot) protocols ([efde8c4](https://github.com/mathiasvr/bluejay/commit/efde8c430d5d256451af9b92b7fb4b5c73d8b9a4))

## [0.1.0](https://github.com/mathiasvr/bluejay/compare/b2a7afbfb86c67aafa7ce7f9fe54047175a1d50a...v0.1.0) (2020-10-18)
Initial version based on BLHeli_S revision 16.7.

- Telemetry encoding method credits to [JazzMaverick](https://github.com/JazzMaverick).

### Features

* Add bidirectional DShot e-period telemetry ([b3b7467](https://github.com/mathiasvr/bluejay/commit/b3b7467852e4d9da7f11545e1bd9e96b4812aa52))


### Performance Improvements

* Prescale DShot thresholds ([c11769a](https://github.com/mathiasvr/bluejay/commit/c11769a5f66dc71f04799ed2f47906ed631c7d2c))
* Prescale DShot thresholds (further) ([5e55c7f](https://github.com/mathiasvr/bluejay/commit/5e55c7f27fc0fc4a1142898748e8961c7ed9f885))
* Reduce DShot decode code ([b2a7afb](https://github.com/mathiasvr/bluejay/commit/b2a7afbfb86c67aafa7ce7f9fe54047175a1d50a))
* Reduce DShot decode code (further) ([6a65bab](https://github.com/mathiasvr/bluejay/commit/6a65babc3bc74bd98bc27770329ef7b896eb7cdb))
* Reduce DShot invert code ([ac6b456](https://github.com/mathiasvr/bluejay/commit/ac6b4567d1dbebd629da044c16e1813fa1e0fa38))
