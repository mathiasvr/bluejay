# Changelog

All notable changes to this project will be documented in this file.

## [0.15](https://github.com/mathiasvr/bluejay/compare/v0.14...v0.15) (2022-01-02)

### Features

* Add braking strength setting ([#15](https://github.com/mathiasvr/bluejay/pull/15)) ([44a163a](https://github.com/mathiasvr/bluejay/commit/44a163a9f6ced4c3fd42c44c4cbf651cf4449bcb))
* Faster brake on stop ([6bfeddc](https://github.com/mathiasvr/bluejay/commit/6bfeddc3d3463d731cbe9d3867b6e83fe1b07225))

### Bug Fixes

* Add missing definition in Q layout ([77f0178](https://github.com/mathiasvr/bluejay/commit/77f0178e9d549b9d7f6c7b00ba88bf451a124b86))
* Adjust telemetry timing on L ESCs ([1670ce2](https://github.com/mathiasvr/bluejay/commit/1670ce2b1089c18e8502224be733e52c1276a81d))
* Disable interrupts when changing clock speed ([c9ed003](https://github.com/mathiasvr/bluejay/commit/c9ed003b4bccf8a3f8e03d38293d63d5ed94e111))
* Improve wait ms accuracy ([0f54d76](https://github.com/mathiasvr/bluejay/commit/0f54d765bd34806aaa20c25d2d94c628798de8b4))
* Make inverted comparator output work on BB1 ([3ffc6b4](https://github.com/mathiasvr/bluejay/commit/3ffc6b4ba9fe4620a13d8673ac0ca5c1db9d8dec))

### Performance Improvements

* Only check brake on stop and RCP timeout when needed ([4961444](https://github.com/mathiasvr/bluejay/commit/49614444e7fa7e592d3e3006658175f932247cc7))


## [0.14](https://github.com/mathiasvr/bluejay/compare/v0.13...v0.14) (2021-07-11)

### Features

* Improve arming safety check ([907c472](https://github.com/mathiasvr/bluejay/commit/907c4726b71ac5d5df377c1fb21b4eda90bc37ed))

### Bug Fixes

* Disable DShot 600 support on BB1 (L) ESCs ([a5cc565](https://github.com/mathiasvr/bluejay/commit/a5cc565c02c8f65809a7424e5f879ef0ff33a980))
* Discrepancy when calculating wait times during startup ([fd9864a](https://github.com/mathiasvr/bluejay/commit/fd9864a06845255cf5e85b043d39add9018d6649))
* Wrong averaging of commutation period during startup phase ([10f0f9b](https://github.com/mathiasvr/bluejay/commit/10f0f9b26c29e33a447dd514c8fbded5b0b6c432))

### Performance Improvements

* Optimize commutation calculations for startup phase ([a668872](https://github.com/mathiasvr/bluejay/commit/a668872e905a6c678a719617e36b35b4ebe1780a))
* Optimize commutation period averaging ([df1fe00](https://github.com/mathiasvr/bluejay/commit/df1fe00ebf89900fbfe1f56b7b1af2a9d0f822bd))
* Optimize commutation period calculations ([f237ec7](https://github.com/mathiasvr/bluejay/commit/f237ec732e5a78254ac75b921704371e7f7e0af3))
* Remove PCA interrupt ([788338e](https://github.com/mathiasvr/bluejay/commit/788338e8d957ffe5e41adbddc68c9bf3d4723856))
* Remove pwm power RAM variables ([17a7a22](https://github.com/mathiasvr/bluejay/commit/17a7a22f64a4a9f8295d6f68ad1f89875f194de6))
* Set max commutation period directly for startup phase ([f4c918f](https://github.com/mathiasvr/bluejay/commit/f4c918fae5d4e36368363512016b1b22bcffc431))


## [0.13](https://github.com/mathiasvr/bluejay/compare/v0.12...v0.13) (2021-05-06)

### Features

* Send telemetry for each DShot packet when off ([90ae235](https://github.com/mathiasvr/bluejay/commit/90ae235481fca247dcc4291d6199f7e7a7ddc871))

### Bug Fixes

* Check RCP timeout in DShot command loop ([ecb70ea](https://github.com/mathiasvr/bluejay/commit/ecb70ea8840ca888d7bcf9d7f88648827c93b735))
* Clear DShot command when RCP is zero ([be52fa6](https://github.com/mathiasvr/bluejay/commit/be52fa64692d779a7697a71880abe179e9ac57b5))
* Switch power off earlier during signal detection ([78de110](https://github.com/mathiasvr/bluejay/commit/78de110ea93fd3c70a01fafe58b3279dc1236e95))


## [0.12](https://github.com/mathiasvr/bluejay/compare/v0.11...v0.12) (2021-04-13)

### Features

* Make startup melody user configurable ([#8](https://github.com/mathiasvr/bluejay/pull/8)) ([3b355fb](https://github.com/mathiasvr/bluejay/commit/3b355fb02a6ac54a26c1f9e6c5d39a94780180a2))

### Bug Fixes

* Avoid entering bootloader during FC reboot ([fb804ea](https://github.com/mathiasvr/bluejay/commit/fb804ea743dae63450f06f7657616f5f570ac9fe))
* Change startup melody length from 64 to 62 notes ([#20](https://github.com/mathiasvr/bluejay/pull/20)) ([e2c249b](https://github.com/mathiasvr/bluejay/commit/e2c249bba2851928fb75ba5ffebb5330132a8249))
* Increase bootloader signal duration ([bffd76e](https://github.com/mathiasvr/bluejay/commit/bffd76eb830c66cada459282271ba6f4cee7d676))
* Port 2 was not skipped by crossbar ([0b15dc3](https://github.com/mathiasvr/bluejay/commit/0b15dc327f0aa753c90eae4a6683b51aefc2e54f))


## [0.11](https://github.com/mathiasvr/bluejay/compare/v0.10...v0.11) (2021-03-30)

- Major refactoring of the ESC layout configuration ([#9](https://github.com/mathiasvr/bluejay/pull/9))

### Features

* Add Z layout ([55eda69](https://github.com/mathiasvr/bluejay/commit/55eda69689249ce5e3946f223289618eca8d42f2))
* Store programmed PWM frequency for display ([047c86b](https://github.com/mathiasvr/bluejay/commit/047c86b95c15c6cdeac47e0e197d30c3af71183f))

### Bug Fixes

* Avoid incorrect reload of the commutation wait timer ([a480fbf](https://github.com/mathiasvr/bluejay/commit/a480fbfdbd8628bd75cf9fa2661ff6496994c56b))

### Performance Improvements

* Optimize usage of startup phase flags ([14dfb1a](https://github.com/mathiasvr/bluejay/commit/14dfb1acc6e2a91325896d5c4adeaeb651b5c88f))


## [0.10](https://github.com/mathiasvr/bluejay/compare/v0.9...v0.10) (2021-02-10)

### Features

* Separate startup and rampup power settings ([ad46bab](https://github.com/mathiasvr/bluejay/commit/ad46bab50605834db0161cde13ec5202e810431f))

### Bug Fixes

* DShot commands could cause invalid direction settings ([30fbf47](https://github.com/mathiasvr/bluejay/commit/30fbf477074d3283b9d1c2b04840768514c8395f))
* Fix and optimize direction handling ([f5911b6](https://github.com/mathiasvr/bluejay/commit/f5911b673e3b1b34f227586d31985e87d502b2f7))


## [0.9](https://github.com/mathiasvr/bluejay/compare/v0.8...v0.9) (2021-01-29)

### ⚠ BREAKING CHANGES

* Change eeprom layout version for beta ([3d30c6c](https://github.com/mathiasvr/bluejay/commit/3d30c6cb590188f9353a2a08b4c336f2acd72c13))

### Features

* Add dithering setting ([4769b19](https://github.com/mathiasvr/bluejay/commit/4769b19696828483365e62d98f4ca3b9fab86ac2))
* Add startup beep setting ([09ff60c](https://github.com/mathiasvr/bluejay/commit/09ff60cbc605a8d3d0ee3e3f68023421184b6e3d))
* Default to medium high timing ([c1b6d3d](https://github.com/mathiasvr/bluejay/commit/c1b6d3dfcb173986463c669763c023980193b698))
* Increase dithering to 11-bit ([054d1d9](https://github.com/mathiasvr/bluejay/commit/054d1d9a2bc7fe783d7bf606d0ae20f7df57185a))
* Startup boost setting ([03544f9](https://github.com/mathiasvr/bluejay/commit/03544f91174244a842f241113984197d49affb64))

### Bug Fixes

* Update telemetry timings ([98ae2d5](https://github.com/mathiasvr/bluejay/commit/98ae2d5706f6908b74358bc19a08176ba097b567))


## [0.8](https://github.com/mathiasvr/bluejay/compare/v0.7...v0.8) (2021-01-21)

### Features

* Add DShot150 support on 24MHz MCUs ([f16cd2c](https://github.com/mathiasvr/bluejay/commit/f16cd2c4da336f40c923c4bdb81b881551ea168d))

### Bug Fixes

* Fix bug in comparator routine ([32ae3df](https://github.com/mathiasvr/bluejay/commit/32ae3dfbfb9db8872762defc18a1dee5d630eb86))

### Performance Improvements

* Optimize comparator wait routine on 48MHz ([661be1b](https://github.com/mathiasvr/bluejay/commit/661be1b9540a6129275975b2a356926fe4251254))


## [0.7](https://github.com/mathiasvr/bluejay/compare/v0.6...v0.7) (2021-01-16)

### Features

* Smoother DShot throttle scaling ([2268e16](https://github.com/mathiasvr/bluejay/commit/2268e16d5f834efb72d91d61f86dddd130c56faa))

### Bug Fixes

* Add delay between beacon beeps ([3b4fad9](https://github.com/mathiasvr/bluejay/commit/3b4fad93e48eb6d6a1500bfd675f9223e0d07f8c))
* Adjust telemetry timing and ensure port is ready ([5ad0a92](https://github.com/mathiasvr/bluejay/commit/5ad0a925aac33828b983e378c746a0e8f329925a))
* Delay stall count reset in case of gradual power down ([1ee21f5](https://github.com/mathiasvr/bluejay/commit/1ee21f55df631fa873c67b8a0bcaef79014c8fc0))
* Fix bug causing excessive startup boost ([98e7de9](https://github.com/mathiasvr/bluejay/commit/98e7de9983c8f1e40f4a741d9eed43063b72e24b))
* Only boost power when stalling from failed starts ([3652e31](https://github.com/mathiasvr/bluejay/commit/3652e3183e2721cf4808ea8043a844ff10cfb591))
* Scale DShot sync timer during signal detection ([36f70ce](https://github.com/mathiasvr/bluejay/commit/36f70ce668d10e6f9feba84af8239f44f05aa00b))

### Performance Improvements

* Optimize startup boost check order ([2c96991](https://github.com/mathiasvr/bluejay/commit/2c96991ae08e6cf17b44bdfb3a2568edf18c7d5a))


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


## [0.2.1](https://github.com/mathiasvr/bluejay/compare/v0.2.0...v0.2.1) (2020-10-25)

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

* Remove legacy (non-DShot) protocols ([efde8c4](https://github.com/mathiasvr/bluejay/commit/efde8c430d5d256451af9b92b7fb4b5c73d8b9a4))

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
