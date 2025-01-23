##############################################################################
# Spectravideo SVI-328 MegaROM
# (c) 2025 Markus Rautopuro
# 

# Use either a 256 kB or 1024 kB version
ROM_VERSION := 1024

# The magic number in the end is the index where game data starts in sector 0 (see rom_simulator.asm or rom_production.asm)
SECTOR0_START_SIMULATOR := 11000
SECTOR0_START := 10097

# If you want to compile a version without MSX ROM support, use 1 here
EXEROM_DISABLE := 0

# If you want to enable a CRC check, use 1 here
CHECK_CRC := 0

# You don't need to modify these
DZX0_ADDRESS := 65468                   # End of memory minus 68 bytes for decompressor (65536-63)
LAUNCHER_ADDRESS := 0x8001              # 0x8000 has the ROM_ID in simulator, so begin at 0x8001			

ifeq (, $(shell which z88dk-z80asm))
	$(error "No z88dk-z80asm in PATH, z88dk (https://github.com/z88dk/z88dk) is required to compile")
endif
ifeq (, $(shell which /Applications/openMSX.app/Contents/MacOS/openmsx))
	$(error "openMSX not found from default location /Applications/openMSX.app, please install https://openmsx.org")
endif
ifeq (, $(shell which node))
	$(error "No node in PATH, Node.js (https://nodejs.org/en) version $(shell cat .nvmrc) is required to compile. You can use 'nvm install' (https://github.com/nvm-sh/nvm) to install the correct version")
endif
ifneq ($(shell node --version), v$(shell cat .nvmrc))
	$(error "Node.js found in path, but it's the wrong version ($(shell node --version)), version $(shell cat .nvmrc) is required to compile. Maybe run 'nvm use'?")
endif
ifeq (, $(shell which zx0))
	$(error "No zx0 in PATH, please install it https://github.com/einar-saukas/ZX0.")
endif
ifeq (, $(shell which m4))
	$(error "No m4 in PATH, please install it https://www.gnu.org/software/m4")
endif

main:
	@echo "Spectravideo SVI-328 MegaROM"
	@echo
	@echo "Please use either 'make production' to compile a production ROM or use 'make simulator' and 'make run'."

build:
	mkdir build

release:
	mkdir release

roms:
	mkdir roms

directories: build release

roms/config.json:
	$(error "Missing roms/config.json. Please create it, see README.md")

validate_config: roms/config.json
	@echo "Making sure that config.json is valid..."
	node js/gamedata.js ${ROM_VERSION} validate-config-only

prepare: directories validate_config
	@echo "Compiling loader..."
	z88dk-z80asm -o=build/loader.bin -m -l -b asm/loader.asm -DDZX0_ADDRESS=${DZX0_ADDRESS}
	@mv asm/loader.lis build/loader.lis
	@rm asm/loader.o
	@scripts/synthetic_opcodes.sh build/loader.lis
	@echo "Loader compiled (`stat -f%z build/loader.bin` bytes)"

	@echo "Creating game data..."
	node js/gamedata.js ${ROM_VERSION} `stat -f%z build/loader.bin` ${SECTOR0_START}
	@echo "Game data created"

	@echo "Compiling launcher with the final game data..."
	z88dk-z80asm -o=build/launcher.bin -DLOADER_SIZE=`stat -f%z build/loader.bin` -DLAUNCHER_ADDRESS=${LAUNCHER_ADDRESS} -DDZX0_ADDRESS=${DZX0_ADDRESS} -DEXEROM_DISABLE=${EXEROM_DISABLE} -DCHECK_CRC=${CHECK_CRC} -m -l -b asm/launcher.asm
	@mv asm/launcher.lis build/launcher.lis
	@rm asm/launcher.o
	@scripts/synthetic_opcodes.sh build/launcher.lis
	zx0 -f build/launcher.bin
	@echo "Launcher compiled (`stat -f%z build/launcher.bin.zx0` bytes compressed)"

prepare_simulator: directories validate_config
	@echo "Compiling loader..."
	z88dk-z80asm -o=build/loader.bin -DSIMULATOR=1 -m -l -b asm/loader.asm -DDZX0_ADDRESS=${DZX0_ADDRESS}
	mv asm/loader.lis build/loader.lis
	rm asm/loader.o
	scripts/synthetic_opcodes.sh build/loader.lis
	@echo "Loader compiled (`stat -f%z build/loader.bin` bytes)"

	@echo "Creating game data..."
	node js/gamedata.js ${ROM_VERSION} `stat -f%z build/loader.bin` ${SECTOR0_START_SIMULATOR} CHECK_CRC=${CHECK_CRC}
	@echo "Game data created"

	@echo "Compiling launcher with the final game data..."
	z88dk-z80asm -o=build/launcher.bin -DLOADER_SIZE=`stat -f%z build/loader.bin` -DLAUNCHER_ADDRESS=${LAUNCHER_ADDRESS} -DDZX0_ADDRESS=${DZX0_ADDRESS} -DEXEROM_DISABLE=${EXEROM_DISABLE} -DSIMULATOR=1 -DCHECK_CRC=${CHECK_CRC} -m -l -b asm/launcher.asm
	mv asm/launcher.lis build/launcher.lis
	rm asm/launcher.o
	scripts/synthetic_opcodes.sh build/launcher.lis
	zx0 -f build/launcher.bin
	@echo "Launcher compiled (`stat -f%z build/launcher.bin.zx0` bytes compressed)"

simulator: directories prepare_simulator
	@echo "Compiling simulator version..."

	z88dk-z80asm -o=release/cartsim1.rom -DSIMULATOR=1 -DSECTOR0_START=${SECTOR0_START_SIMULATOR} -DLAUNCHER_ADDRESS=${LAUNCHER_ADDRESS} -DDZX0_ADDRESS=${DZX0_ADDRESS} -DEXEROM_DISABLE=${EXEROM_DISABLE} -m -l -b asm/rom_simulator_first.asm
	@mv asm/rom_simulator_first.lis build/rom_simulator_first.lis
	@rm asm/rom_simulator_first.o
	@scripts/synthetic_opcodes.sh build/rom_simulator_first.lis

	z88dk-z80asm -o=release/cartsim2.rom -DSIMULATOR=1 -DLAUNCHER_ADDRESS=${LAUNCHER_ADDRESS} -DDZX0_ADDRESS=${DZX0_ADDRESS} -DEXEROM_DISABLE=${EXEROM_DISABLE} -m -l -b asm/rom_simulator_second.asm
	@mv asm/rom_simulator_second.lis build/rom_simulator_second.lis
	@rm asm/rom_simulator_second.o

	@printf "Magic number (use this in makefile): "
	@cat release/cartsim1.map | grep MAGIC_NUMBER | scripts/extract_magic.sh
	@printf "Maximum compressed ROM size in this build: "
	@scripts/extract_max_game_size.sh build/launcher.map
	@echo "Simulator version (release/cartsim1.rom and release/cartsim2.rom) compiled, use 'make run' to launch the simulator"

NUM_SECTORS := $(shell echo $(ROM_VERSION) / 16 | bc)
SECTOR_FILES := $(foreach n,$(shell seq 0 $(shell echo $(NUM_SECTORS) - 1 | bc)),build/sector$(n).bin)

production: directories prepare
	@echo "Compiling a ${ROM_VERSION} kB ROM..."
	m4 asm/rom_production.asm -DROM_ID=0 > build/rom${ROM_VERSION}.asm
	z88dk-z80asm -o=build/sector0.bin -DSECTOR0_START=${SECTOR0_START} -DLAUNCHER_ADDRESS=${LAUNCHER_ADDRESS} -DDZX0_ADDRESS=${DZX0_ADDRESS} -m -l -b -DROM_ID=0 build/rom${ROM_VERSION}.asm -I=asm
	@scripts/synthetic_opcodes.sh build/rom${ROM_VERSION}.lis

	@for rom_id in $(shell seq 1 `echo $(NUM_SECTORS) - 1 | bc`); do \
		echo Compiling ROM part $$rom_id... || exit 1; \
		m4 asm/rom_production.asm -DROM_ID=$$rom_id > build/rom${ROM_VERSION}.asm; \
		z88dk-z80asm -o=build/sector$$rom_id.bin build/rom${ROM_VERSION}.asm -DROM_ID=$$rom_id -b -I=asm; \
	done

	@cat ${SECTOR_FILES} > release/cart${ROM_VERSION}.rom

	@printf "Magic number (use this in makefile): "
	@cat build/sector0.map | grep MAGIC_NUMBER | scripts/extract_magic.sh
	@printf "Maximum compressed ROM size in this build: "
	@scripts/extract_max_game_size.sh build/launcher.map
	@echo "${ROM_VERSION} kB version compiled (release/cart${ROM_VERSION}.rom)"

run:
	@echo "Launching simulator version in openMSX..."
	scripts/extract_breakpoints.sh > build/setbreakpoints.tcl
	scripts/extract_symbols.sh > build/symbols.lst
	@echo "debug symbols load build/symbols.lst" >> build/setbreakpoints.tcl
	/Applications/openMSX.app/Contents/MacOS/openmsx -machine "Spectravideo_SVI-328" -cart "release/cartsim1.rom" -script "build/setbreakpoints.tcl"

clean: build
	rm build/*
	rm release/*

test:
	z88dk-z80asm -o=release/test.rom -DSIMULATOR=1 -m -l -b asm/test.asm
	mv asm/test.lis build/
	mv release/test.map build/
	rm asm/test.o
	scripts/synthetic_opcodes.sh build/test.lis

	@echo "Launching simulator version in openMSX..."
	scripts/extract_breakpoints.sh > build/setbreakpoints.tcl
	scripts/extract_symbols.sh > build/symbols.lst
	@echo "debug symbols load build/symbols.lst" >> build/setbreakpoints.tcl
	/Applications/openMSX.app/Contents/MacOS/openmsx -machine "Spectravideo_SVI-328" -cart "release/test.rom" -script "build/setbreakpoints.tcl"