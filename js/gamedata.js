const fs = require('fs')
const path = require('path')

const romsPath = 'roms'
const configFileName = 'roms.json'
const configFile = `${romsPath}/${configFileName}`

const ROM_TYPES = {
    'cas.16.zx0': 0x00,
    'rom.32.zx0': 0x01,
    'cas.16': 0x02,
    'cas.8': 0x03,
    'msx.32.pletter.1': 0x04, // Part 1 of the 32 kB MSX ROM
    'msx.32.pletter.2': 0x05, // Part 2 of the 32 kB MSX ROM
    'msx.32.zx0.1': 0x06, // Part 1 of the 32 kB MSX ROM
    'msx.32.zx0.2': 0x07, // Part 2 of the 32 kB MSX ROM
    'msx.16.zx0': 0x08,
    'rom.48.zx0.1': 0x09, // Part 1 (32 kB) of the 48 kB ROM
    'rom.48.zx0.2': 0x0a, // Part 2 (16 kB) of the 48 kB ROM
    'rom.48.zx0': 0x0b, // Single block 48 kB ROM
    'cas.len.zx0': 0x0c // Variable length cas image
}

const GAME_TYPES = (() => {
    const gameTypesSet = new Set()
    for (const key of Object.keys(ROM_TYPES)) {
        gameTypesSet.add(key.replace(/\.[1-2]$/, ''))
    }
    return Array.from(gameTypesSet)
})()

const SECTOR_SIZE = 16384
const GAMES_ON_PAGE = 36

const config = JSON.parse(fs.readFileSync(configFile, 'utf8'))
const args = process.argv.slice(2)

const ROM_VERSION = parseInt(args[0], 10)

if (isNaN(ROM_VERSION) || (ROM_VERSION != 256 && ROM_VERSION != 1024)) {
    console.error('Please provide a valid ROM_VERSION (256 or 1024) as the first parameter.')
    process.exit(1)
}

const buildDir = path.resolve('build')
if (!fs.existsSync(buildDir)) {
    console.error("Please create 'build' directory.")
    process.exit(1)
}

try {
    validateConfig()
} catch (error) {
    console.error(`Validation failed: ${error.message}`)
    process.exit(1)
}

if (args.includes('validate-config-only')) {
    console.log(`Validation passed: ${configFile} is valid.`)
    process.exit(0)
}

const CHECK_CRC = args.includes('CHECK_CRC=1')
console.log("Check CRC:", CHECK_CRC)

let filteredArgs = args.filter(arg => !arg.includes("CHECK_CRC"))

if (filteredArgs.length !== 3) {
    console.error('Please provide ROM_VERSION (256 or 1024), LOADER_SIZE, SECTOR0_GAME_START as command-line arguments, or use validate-config-only.')
    process.exit(1)
}


const LOADER_SIZE = parseInt(filteredArgs[1], 10)
const SECTOR0_GAME_START = parseInt(filteredArgs[2], 10)

if (isNaN(LOADER_SIZE) || isNaN(SECTOR0_GAME_START)) {
    console.error('LOADER_SIZE, SECTOR0_GAME_START must be valid integers.')
    process.exit(1)
}

const SECTOR0_SIZE = SECTOR_SIZE - SECTOR0_GAME_START - LOADER_SIZE - 1
const SECTOR1PLUS_SIZE = SECTOR_SIZE - LOADER_SIZE - 1
const SECTOR_COUNT = ROM_VERSION / 16

console.log(`Loader size: ${LOADER_SIZE} bytes.`)
console.log(`Sector 0 game start index: ${SECTOR0_GAME_START} bytes.`)
console.log(`Sector 0 size: ${SECTOR0_SIZE} bytes.`)
console.log(`Sector 1+ size: ${SECTOR1PLUS_SIZE} bytes.`)

function validateConfig() {
    if (!Array.isArray(config)) {
        throw new Error(`The ${configFileName} JSON is not an array.`)
    }

    config.forEach((game, gameIndex) => {
        if (typeof game !== 'object' || game === null) {
            throw new Error(`Game definition at index ${gameIndex} is not an object.`)
        }

        if (!game.hasOwnProperty('name')) {
            throw new Error(`Game at index ${gameIndex} is missing required field 'name'`)
        }

        // FIXME: Add a check that there are no games or files with the same name
        // FIXME: Add a check that 'jump' is not used (because it's reserved) in MSX ROMS
        // FIXME: Add a check that 'jump', 'load' and 'crc16' contain valid parsable values

        if (!game.hasOwnProperty('type') || !GAME_TYPES.includes(game.type)) {
            throw new Error(
                `Invalid type "${game.type}" in game ${gameIndex}. You must specify field 'type' with one of: ${GAME_TYPES.join(', ')}`
            )
        }

        switch (game.type) {
            case 'rom.48.zx0':
                if (!game.hasOwnProperty('file') && !game.hasOwnProperty('files')) {
                    throw new Error(`Game at index ${gameIndex} is missing required field 'file' or 'files'`)
                }
                if (game.hasOwnProperty('files') && game.files.length != 2) {
                    throw new Error(`Game at index ${gameIndex} with type ${game.type} should have 2 files defined`)
                }
                break
            case 'msx.32.zx0':
            case 'msx.32.pletter':
                if (!game.hasOwnProperty('files')) {
                    throw new Error(`Game at index ${gameIndex} is missing required field 'files'`)
                }
                if (game.files.length != 2) {
                    throw new Error(`Game at index ${gameIndex} with type ${game.type} should have 2 files defined`)
                }
                break
            case 'cas.len.zx0':
                if (!game.hasOwnProperty('file')) {
                    throw new Error(`Game at index ${gameIndex} is missing required field 'file'`)
                }
                if (!game.hasOwnProperty('length')) {
                    throw new Error(`Game at index ${gameIndex} is required to have the length of the compressed image specified in 'length'`)
                }
            default:
                if (!game.hasOwnProperty('file')) {
                    throw new Error(`Game at index ${gameIndex} is missing required field 'file'`)
                }
                break
        }
    })
}

function defaultLoadFor(fileType) {
    switch (fileType) {
        case 'msx.32.zx0.1':
        case 'msx.32.zx0.2':
        case 'msx.32.pletter.1':
        case 'msx.32.pletter.2':
        case 'msx.16.zx0':
            return "0x8800"
        case 'rom.32.zx0':
            return "0x0000"
        case 'rom.48.zx0':
        case 'rom.48.zx0.1':
            return "0x0000"
        case 'rom.48.zx0.2':
            return "0x8000"
        case 'cas.16.zx0':
        case 'cas.16':
        case 'cas.8':
            return "0x8800"
    }
}

function defaultJumpFor(fileType) {
    switch (fileType) {
        case 'msx.32.zx0.1':
        case 'msx.32.zx0.2':
        case 'msx.32.pletter.1':
        case 'msx.32.pletter.2':
        case 'msx.16.zx0':
        case 'rom.48.zx0.1':
            return undefined
        case 'rom.32.zx0':
        case 'rom.48.zx0.2':
        case 'rom.48.zx0':
            return "0x0000"
        case 'cas.16.zx0':
        case 'cas.16':
        case 'cas.8':
            return "0x8800"
    }
}

const files = (() => {
    let files = []

    config.forEach((game, gameIndex) => {
        let fileNames = []
        game.firstFileIndex = files.length
        if (game.hasOwnProperty('files')) {
            game.files.forEach((fileName) => {
                fileNames.push(fileName)
            })
        } else {
            fileNames.push(game.file)
        }
        fileNames.forEach((fileName, index) => {
            let fileType = game.type + ((fileNames.length > 1) ? "." + (index + 1) : "")
            if (!ROM_TYPES.hasOwnProperty(fileType)) {
                throw new Error(`Can't find type mapping for ${fileType} for file ${fileNime}`)
            }
            try {
                files.push({
                    fileName: fileName,
                    gameName: game.name,
                    type: fileType,
                    typeCode: ROM_TYPES[fileType],
                    size: fs.statSync(romsPath + "/" + fileName).size,
                    load: game.load ?? defaultLoadFor(fileType),
                    jump: game.jump ?? defaultJumpFor(fileType),
                    length: game.length,
                    crc16: game.crc16 ?? "0x0000"
                })
            } catch (error) {
                throw new Error(`Failed to read file ${fileName}: ${error.message}`)
            }
        })

    })

    return files
})()

let currentSector = 0
let currentIndex = SECTOR0_GAME_START
let spaceLeft = SECTOR0_SIZE
let bytesUsed = 0

let filePartData = []

files.forEach((file) => {
    console.log(`File ${file.fileName} (size ${file.size})`)

    let fileOffset = 0

    function processFile(size, depth = 0) {
        if (depth >= 3) {
            throw new Error(`File ${file.fileName} (size ${file.size}) is too large, and can't fit to 3 blocks`)
        }

        if (depth == 0) {
            file.startSector = currentSector
            file.startIndex = currentIndex
        }

        let write = Math.min(size, spaceLeft)
        filePartData.push({
            sector: currentSector,
            fileName: file.fileName,
            offset: fileOffset,
            length: write
        })

        file[`size${depth}`] = write
        spaceLeft -= write
        size -= write
        fileOffset += write
        bytesUsed += write

        if (size <= spaceLeft) {
            console.log(` - Part ${depth} at sector ${currentSector}, index ${currentIndex}: ${write} bytes - file completed (${spaceLeft} bytes left in sector)`)

            currentIndex += write
        } else {
            console.log(` - Part ${depth} at sector ${currentSector}, index ${currentIndex}: ${write} bytes, ${size} bytes of file left (${spaceLeft} bytes left in sector)`)
    
            currentSector++
            currentIndex = LOADER_SIZE
            spaceLeft = SECTOR1PLUS_SIZE
            processFile(size, depth + 1)
        }
    }
   
    processFile(file.size)
})

function writeSectorFiles() {
    let sectorData = []
    let sectorIndex = -1
    filePartData.forEach((filePart) => {
        const fileBuffer = fs.readFileSync(romsPath + "/" + filePart.fileName)
        if (filePart.sector == sectorIndex) {
            sectorData[sectorData.length - 1].data.push(
                fileBuffer.subarray(filePart.offset, filePart.offset + filePart.length)
            )
        } else if (filePart.sector == sectorIndex + 1) {
            sectorIndex++
            sectorData.push({
                index: sectorIndex,
                data: [
                    fileBuffer.subarray(filePart.offset, filePart.offset + filePart.length)
                ]
            })
        } else {
            throw new Error("Configuration error")
        }
    })

    if (spaceLeft > 0) {
        sectorData[sectorData.length - 1].data.push(
            Buffer.alloc(spaceLeft)
        )
    }

    for (let i = 0; i < SECTOR_COUNT - (currentSector + 1); i++) {
        sectorData.push({
            index: sectorData.length,
            data: [
                Buffer.alloc(SECTOR1PLUS_SIZE)
            ]
        })
    }

    sectorData.forEach((sector) => {
        const sectorFileName = path.join(buildDir, `data_sector${sector.index}.bin`)
        const sectorData = Buffer.concat(sector.data)
        fs.writeFileSync(sectorFileName, sectorData)
        console.log(`Created ${sectorFileName}, size ${sectorData.length} bytes`)
    })
}

function shortenGameName(gameName) {
    if (gameName.length <= 17) {
        return gameName
    }

    const words = gameName.split(" ")
    let shortenedName = words[0]

    for (let i = 1; i < words.length; i++) {
        const nextWord = words[i]
        const candidateName = `${shortenedName} ${nextWord}.`

        if (candidateName.length > 17) {
            return `${shortenedName} ${nextWord[0]}.`
        }

        shortenedName += ` ${nextWord}`
    }

    return `${shortenedName}.`
}

function gameIndexText(index) {
    let pageIndex = index % GAMES_ON_PAGE
    let page = (index / GAMES_ON_PAGE | 0) + 1

    return "page " + page + ", game " + String.fromCharCode(pageIndex > 25 ? pageIndex - 26 + 48 : pageIndex + 65)
}

function generateGameDataAsm() {
    const output = []

    const sortedGames = {}

    config.forEach((game) => {
        sortedGames[game.name] = `Game${game.firstFileIndex + 1}Data`
    })

    const sortedGameNames = Object.keys(sortedGames).sort()
    sortedGameNames.forEach((gameName, index) => {
        output.push(`    dw ${sortedGames[gameName]} ; ${index} ${gameIndexText(index)} \"${gameName}\"`)
    })

    output.push('')

    files.forEach((file, fileIndex) => {
        const gameDataLabel = `Game${fileIndex + 1}Data`

        output.push(`${gameDataLabel}: ; \"${file.gameName}\"`)
        output.push(`    db 0x${ROM_TYPES[file.type].toString(16)} ; Type: ${file.type}`)
        output.push(`    db ${file.startSector} ; Start of the game data is located in this sector`)
        output.push(`    dw ${file.load} ; Load address`)

        if (file.jump != undefined) {
            output.push(`    dw ${file.jump} ; Jump address`)
        } else {
            output.push(`    dw 0x0000 ; Jump address is not used in this file type`)
        }

        // FIXME: Add better error handling
        if (file.type.includes("msx")) {
            // 10 is a magic number, must be at least 'delta' value of zx0 compressed files (usually 2-3)
            const compressedLocation = parseInt(file.load, 16) + 16384 - file.size + 10 
            output.push(`    dw ${compressedLocation} ; For ZX0 packed MSX game parts, use the lowest memory address where the compressed image can reside without being overwritten`)
        } else if (file.type.includes("rom.48.zx0.2")) {
            const compressedLocation = parseInt(file.load, 16) + 16384 - file.size + 10 
            output.push(`    dw ${compressedLocation} ; For ZX0 packed 48k game second part, use the lowest memory address where the compressed image can reside without being overwritten`)
        } else if (file.type.includes("cas.len.zx0")) {
            const compressedLocation = parseInt(file.load, 16) + parseInt(file.length) - file.size + 10 
            output.push(`    dw ${compressedLocation} ; For ZX0 packed variable length cas games, use the lowest memory address where the compressed image can reside without being overwritten`) 
        } else {
            output.push(`    dw 0x0000 ; Compressed data location is not used in this file type`)
        }
        output.push(`    dw ${file.startIndex} ; Start address in the 16 kB sector`)
        output.push(`    dw ${file.size0} ; Size of the game data in first sector`)
        output.push(`    dw ${file.size1 ?? 0} ; Size of the game data in second sector, if any`)
        output.push(`    dw ${file.size2 ?? 0} ; Size of the game data in third sector, if any`)

        if (CHECK_CRC) {
            output.push(`    dw ${file.crc16} ; CRC16 checksum of the uncompressed image`)
        }

        output.push('')
    })

    let pages = (sortedGameNames.length / GAMES_ON_PAGE | 0 ) + 1
    output.push(`GamePages: db ${pages}`)

    output.push('GamePageData:')

    for (let i = 1; i <= pages; i++) {
        if (i < pages) {
            output.push(`    db ${GAMES_ON_PAGE}`)
        } else {
            output.push(`    db ${sortedGameNames.length - (i - 1) * GAMES_ON_PAGE}`)
        }
        output.push("    dw GameNames" + i)
    }

    sortedGameNames.forEach((gameName, index) => {
        let pageIndex = index % GAMES_ON_PAGE
        let page = (index / GAMES_ON_PAGE | 0) + 1
        if (pageIndex == 0) {
            output.push('')
            output.push(`GameNames${page}:`)
        }
        output.push(`    db "${shortenGameName(gameName)}", 0 ; ${sortedGames[gameName]}`)
    })

    const asmFilePath = path.join(buildDir, 'gamedata.asm')
    fs.writeFileSync(asmFilePath, output.join('\n'), 'utf8')
    console.log(`Created gamedata.asm to ${asmFilePath}`)
}

const bytesFree = SECTOR0_SIZE + SECTOR1PLUS_SIZE * (SECTOR_COUNT - 1) - bytesUsed

if (bytesFree < 0) {
    console.error(`The games do not fit on the ROM, please free up ${-bytesFree} bytes`)
    process.exit(1)
}
console.log(`${currentSector + 1} sectors used out of ${SECTOR_COUNT}.`)
console.log(`The games use ${bytesUsed} bytes, the ROM has still ${bytesFree} bytes free.`)

writeSectorFiles()
generateGameDataAsm()

console.log('Processing complete!')