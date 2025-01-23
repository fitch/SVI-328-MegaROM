const fs = require('fs')

function computeCRC16(buffer, polynomial = 0x1021, initialValue = 0xFFFF) {
    let crc = initialValue

    for (const byte of buffer) {
        crc ^= byte << 8

        for (let i = 0; i < 8; i++) {
            if (crc & 0x8000) {
                crc = (crc << 1) ^ polynomial
            } else {
                crc <<= 1
            }
            crc &= 0xFFFF
        }
    }

    return crc
}

const args = process.argv.slice(2)
if (args.length !== 1) {
    console.error('Usage: node crc16.js <file_path>')
    process.exit(1)
}

const filePath = args[0]

try {
    const fileBuffer = fs.readFileSync(filePath)

    const crc16 = computeCRC16(fileBuffer)

    console.log(`CRC16 Checksum: 0x${crc16.toString(16).toLowerCase().padStart(4, '0')}`)
} catch (error) {
    console.error(`Error reading file: ${error.message}`)
    process.exit(1)
}
