#!/usr/bin/env python3
#
# This file is part of efm8load. efm8load is free software: you can
# redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, version 3.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51
# Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Copyright 2020 fishpepper.de
#
import argparse
import operator
import sys

import crcmod
import serial
from intelhex import IntelHex


# make sure to install the python3 modules for serial, crcmod, and pip3:
# sudo apt intstall python3-crcmod python3-serial python3-pip
# if you are missing the intelhex package, you can install it afterwars by
# pip3 install intelhex --user

class COMMAND:
    IDENTIFY = 0x30
    SETUP    = 0x31
    ERASE    = 0x32
    WRITE    = 0x33
    VERIFY   = 0x34
    RESET    = 0x36

class RESPONSE:
    ACK         = 0x40
    RANGE_ERROR = 0x41
    BAD_ID      = 0x42
    CRC_ERROR   = 0x43
    TO_STR = { ACK: "ACK", RANGE_ERROR : "RANGE_ERROR", BAD_ID : "BAD_ID", CRC_ERROR : "CRC_ERROR" }

    @staticmethod
    def to_string(res):
        if res in RESPONSE.TO_STR:
            return RESPONSE.TO_STR[res]
        else:
            return "unknown response"

class EFM8Loader:
    """A python implementation of the EFM8 bootloader protocol"""

    devicelist = {
                    # DEVICE_ID : [ NAME, { DICT OF VARIANT_IDS } ]
                    #            VARIANT_ID: VARIANT_ID, VARIANT_NAME, FLASH_SIZE, PAGE_SIZE, SECURITY_PAGE_SIZE]
                     0x16 : ["EFM8SB2", { } ],
                     0x25 : ["EFM8SB1", {
                                         0x01: ["EFM8SB10F8G_QFN24", 8*1024, 512, 512],
                                         0x02: ["EFM8SB10F8G_QSOP24", 8*1024, 512, 512],
                                         0x03: ["EFM8SB10F8G_QFN20", 8*1024, 512, 512],
                                         0x06: ["EFM8SB10F4G_QFN20", 4*1024, 512, 512],
                                         0x09: ["EFM8SB10F2G_QFN20", 2*1024, 512, 512]
                                         }],

                     0x30 : ["EFM8BB1", {
                                         0x01: ["EFM8BB10F8G_QSOP24", 8*1024, 512, 512 ],
                                         0x02: ["EFM8BB10F8G_QFN20" , 8*1024, 512, 512 ],
                                         0x03: ["EFM8BB10F8G_SOIC16", 8*1024, 512, 512 ],
                                         0x05: ["EFM8BB10F4G_QFN20" , 4*1024, 512, 512 ],
                                         0x08: ["EFM8BB10F2G_QFN20" , 2*1024, 512, 512 ],
                                         0x12: ["EFM8BB10F8I_QFN20" , 8*1024, 512, 521 ]
                                         }],
                      0x32 : ["EFM8BB2", {
                                         0x01: ["EFM8BB22F16G_QFN28" , 16*1024, 512, 512],
                                         0x02: ["EFM8BB21F16G_QSOP24", 16*1024, 512, 512],
                                         0x03: ["EFM8BB21F16G_QFN20" , 16*1024, 512, 512]
                                         }],
                      0x34 : ["EFM8BB3", {
                                         0x01: ["EFM8BB31F64G-QFN32" , 64*1024, 512, 512],
                                         }]
                 }

    def __init__(self, port, baud, debug = False):
        self.debug           = debug
        self.serial          = serial.Serial()
        self.serial.port     = port
        self.serial.baudrate = baud
        self.serial.timeout  = 1
        #defaults
        self.flash_page_size = 512
        self.flash_size      = 16*1024
        self.flash_security_size = 512
        #open serial connection
        self.open_port()

    def __del__(self):
        self.close_port()

    def open_port(self):
        print("> opening port '%s' (%d baud)" % (self.serial.port, self.serial.baudrate))
        try:
            self.serial.open()
        except:
            sys.exit("ERROR: failed to open serial port '%s'!" % (self.serial.port))

    def close_port(self):
        try:
            self.serial.close()
        except serial.SerialException:
            sys.exit("ERROR: failed to close serial port")

    def send_autobaud_training(self):
        if (self.debug): print("> sending training char 0xFF")
        for i in range(2):
            self.send_byte(0xff)

    def send_byte(self, b):
        try:
            self.serial.write(b.to_bytes(1, 'little'))
        except serial.SerialException:
            sys.exit("ERROR: failed to send byte to serial port")

    def identify_chip(self):
        print("> checking for device")

        #send autobaud training
        self.send_autobaud_training()

        #enable flash access
        self.enable_flash_access()

        #we will now iterate through all known device ids
        for device_id, device in self.devicelist.items():
            device_name = device[0]
            variant_ids = device[1]
            if (self.debug): print("> checking for device %s" % (device_name))
            for variant_id, config in variant_ids.items():
                #test all possible variant ids
                variant_name = config[0]

                if (self.check_id(device_id, variant_id)):
                    print("> success, detected %s cpu (variant %s)" % (device_name, variant_name))
                    #set up chip data
                    self.flash_size               = config[1]
                    self.flash_page_size          = config[2]
                    self.flash_security_page_size = config[3]
                    print("> detected %s cpu (variant %s, flash_size=%d, pagesize=%d)" % (device_name, variant_name, self.flash_size, self.flash_page_size))
                    return 1

        #we did not detect a known device, scann all posible ids:
        for device_id in range(0xFF):
            print("\r> checking device_id 0x%02X..." % (device_id), end="")
            sys.stdout.flush()
            for variant_id in range(24):
                if (self.check_id(device_id, variant_id)):
                    sys.exit("\n> ERROR: unknown device detected: id=0x%02X, variant=0x%02X\n"\
                             "         please add it to the devicelist. will exit now\n" % (device_id, variant_id))

        sys.exit("> ERROR: could not find any device...")

    def send_reset(self):
        print("> send reset command")

        if (self.send(COMMAND.RESET, [255, 255]) == RESPONSE.ACK):
            print("> success, device restarted...")

    def send(self, cmd, data):
        length = len(data)

        #check length
        if (length < 2) or (length > 130):
            sys.exit("> ERROR: invalid data length! allowed 2...130, got %d" % (length))

        try:
            if (self.debug):
                data_str = "".join('0x{:02x} '.format(x) for x in data[:16])
                if (length > 16): data_str = data_str + "..."
                print("> sending $ len=%d cmd=0x%02X data={ %s}" % (length, cmd, data_str))
            self.serial.write(b'$')
            self.serial.write((length + 1).to_bytes(1, 'little'))
            self.serial.write(cmd.to_bytes(1, 'little'))
            self.serial.write(bytearray(data))

            #read back reply
            res_bytes = self.serial.read(1)
            #res_bytes = b"\x40"
            if (len(res_bytes) != 1):
                sys.exit("> ERROR: serial read timed out")
                return 0
            else:
                res = res_bytes[0]
                if(self.debug): print("> reply 0x%02X" % (res))
                return res

        except serial.SerialException:
            sys.exit("ERROR: failed to send data")


    def check_id(self, device_id, derivative_id):
        #verify that the given id matches the target
        return self.send(COMMAND.IDENTIFY, [device_id, derivative_id]) == RESPONSE.ACK

    def enable_flash_access(self):
        res = self.send(COMMAND.SETUP, [0xA5, 0xF1, 0x00])
        if (res != RESPONSE.ACK):
            sys.exit("> ERROR enabling flash access, error code 0x%02X (%s)" % (res, RESPONSE.to_string(res)))

    def erase_page(self, page):
        start = page * self.flash_page_size
        end   = start + self.flash_page_size-1
        start_hi = (start >> 8) & 0xFF
        start_lo = start & 0xFF
        print("> will erase page %d (0x%04X-0x%04X)" % (page, start, end))
        return self.send(COMMAND.ERASE, [start_hi, start_lo])

    def write(self, address, data):
        if (len(data) > 128):
            sys.exit("ERROR: invalid chunksize, maximum allowed write is 128 bytes (%d)" % (len(data)))
        #print some of the data as debug info
        if (len(data) > 8):
            data_excerpt = "".join('0x{:02x} '.format(x) for x in data[:4]) + \
                           "... " + \
                           "".join('0x{:02x} '.format(x) for x in data[-4:])
        else:
            data_excerpt = "".join('0x{:02x} '.format(x) for x in data)

        print("> write at 0x%04X (%3d): %s" % (address, len(data), data_excerpt))

        #send request
        address_hi = (address >> 8) & 0xFF
        address_lo = address & 0xFF
        res = self.send(COMMAND.WRITE, [address_hi, address_lo] + data)
        if not (res == RESPONSE.ACK):
            sys.exit("ERROR: write failed at address 0x%04X (response = %s)" % (address, RESPONSE.to_string(res)))
        return res

    def verify(self, address, data):
        length = len(data)
        crc16 = crcmod.predefined.mkCrcFun('xmodem')(bytearray(data))

        if (self.debug): print("> verify address 0x%04X (len=%d, crc16=0x%04X)" % (address, length, crc16))
        start_hi = (address >> 8) & 0xFF
        start_lo = address & 0xFF
        end      = address + length - 1
        end_hi   = (end >> 8) & 0xFF
        end_lo   = end & 0xFF
        crc_hi   = (crc16 >> 8) & 0xFF
        crc_lo   = crc16 & 0xFF
        res = self.send(COMMAND.VERIFY, [start_hi, start_lo] + [end_hi, end_lo] + [crc_hi, crc_lo])
        return res

    def download(self, filename):
        print("> dumping flash content to '%s'" % filename)
        print("> please note that this will take long")

        #check for chip
        self.identify_chip()

        self.debug = False

        #send autobaud training character
        self.send_autobaud_training()

        #enable flash access
        self.enable_flash_access()

        #the bootloader protocol does not allow reading flash
        #however it allows to verify written bytes
        #we will exploit this feature to dump the flash contents
        #for now assume 8kb flash
        flash_size = 8 * 1024
        ih = IntelHex()
        for address in range(flash_size):
            #test one byte by byte
            #first check 0x00
            byte = 0
            if (self.verify(address, [byte]) == RESPONSE.ACK):
                ih[address] = byte
            else:
                #now start with 0xFF (empty flash)
                for byte in range(0xFF, -1, -1):
                    if (self.verify(address, [byte]) == RESPONSE.ACK):
                        #success, the flash content on this address euals <byte>
                        ih[address] = byte
                        break
            print("\r> flash[0x%04X] = 0x%02X" % (address, byte), end="")
            sys.stdout.flush()

        print("\n> finished")

        #done, all flash contents have been read, now store this to the file
        ih.write_hex_file(filename)


    def upload(self, filename):
        print("> uploading file '%s'" % (filename))

        #identify chip
        self.identify_chip()

        #read hex file
        ih = IntelHex()
        ih.loadhex(filename)

        #send autobaud training character
        self.send_autobaud_training()

        #enable flash access
        self.enable_flash_access()

        #erase pages where we are going to write
        self.erase_pages_ih(ih)

        #write all data bytes
        self.write_pages_ih(ih)
        self.verify_pages_ih(ih)

    def erase_pages_ih(self, ih):
        """ erase all pages that are occupied """
        last_address = ih.addresses()[-1]
        last_page = int(last_address / self.flash_page_size)
        for page in range(last_page+1):
            start = page * self.flash_page_size
            end   = start +  self.flash_page_size-1
            page_used = False
            for x in ih.addresses():
                if x >= start and x <= end:
                    page_used = True
                    break
            #always erase page 0 to retain bootloader access
            if (page == 0) or (page_used):
                self.erase_page(page)

    def write_pages_ih(self, ih):
        """ write all segments from this ihex to flash"""
        #NOTE: it is important to keep flash location 0
        #      equal to 0xFF until we are almost finished...
        #      therefore the bootloader will still be functional in case
        #      something goes wrong in the process.
        #      (the bootloader will be executed as long the first flash
        #      content equals 0xFF)
        byte_zero = -1
        for start,end in ih.segments():
            print("> writing segment 0x%04X-0x%04X" % (start, end-1))

            #fetch data
            data = []
            for x in range(start,end):
                data.append(ih[x])
            #write in 128byte blobs
            data_pos = 0
            #keep byte zero 0xFF in order to keep bootloader active (for now)
            if (start == 0):
                print("> delaying write of flash[0] = 0x%02X to the end" % (data[0]))
                byte_zero = data[0]
                start = start + 1
                data.pop(0)
            while ((data_pos + start) < end):
                length = min(128, end - (data_pos + start))
                self.write(start + data_pos, data[data_pos:data_pos+length])
                data_pos = data_pos + length

            #now verify this segment
            print("> verifying segment... ", end="")
            sys.stdout.flush()
            if (self.verify(start, data) == RESPONSE.ACK):
                print("OK")
            else :
                sys.exit("FAILURE. will abort now\n")

        #all bytes except byte zero were written, do this now
        if (byte_zero != -1):
            print("> will now write flash[0] = 0x%02X" % (byte_zero))
            res = self.write(0, [byte_zero])
            if (res != RESPONSE.ACK):
                print("> ERROR, write of flash[0] failed (response = %s)" % (RESPONSE.to_string(res)))
                self.restore_bootloader_autostart()
                sys.exit("FAILED")
            #verify
            res = self.verify(0, [byte_zero])
            if (res != RESPONSE.ACK):
                print("> ERROR, verify of flash[0] failed (response = %s)" % (RESPONSE.to_string(res)))
                self.self.restore_bootloader_autostarti()
                sys.exit("FAILED")

    def restore_bootloader_autostart(self):
        #the bootloader will always start if flash[0] = 0xFF
        #in case something went wrong during programming,
        #call this in order to clear page 0 so that the bootloader
        #will always start
        print("> will now erase page 0 in order to re-enable bootloader autorun");
        self.erase_page(0)

    def verify_pages_ih(self, ih):
        """ verify written data """
        #do a pagewise compare to find the position of
        #the mismatch
        for start,end in ih.segments():
            print("> verifying segment 0x%04X-0x%04X... " % (start, end-1), end="")
            sys.stdout.flush()

            #fetch data
            data = []
            for x in range(start,end):
                data.append(ih[x])

            #calc crc16
            if (self.verify(start, data) == RESPONSE.ACK):
                print("OK")
            else :
                sys.exit("FAILURE. will abort now\n")

        return 1

if __name__ == "__main__":
    argp = argparse.ArgumentParser(description='efm8load - a plain python implementation for the EFM8 usart bootloader protocol')

    group = argp.add_mutually_exclusive_group()
    group.add_argument("-w", "--write", metavar="filename", help="upload the given hex file to the flash memory")
    group.add_argument("-r", "--read", metavar="filename", help="download the flash memory contents to the given filename") #action="store_true", nargs=1)
    group.add_argument("-i", "--identify", help="identify the chip", action="store_true")
    group.add_argument("-s", "--reset", help="send reset command", action="store_true")

    #argp.add_argument('filename', help='firmware file to upload to the mcu')
    argp.add_argument('-b', '--baudrate', type=int, default=115200, help='baudrate (default is 115200 baud)')
    argp.add_argument('-p', '--port', default="/dev/ttyUSB0", help='port (default is /dev/ttyUSB0)')
    argp.add_argument('-v', '--verbose', action='store_true', help='Verbose mode')
    args = argp.parse_args()

    print("########################################")
    print("# efm8load.py - (c) 2020 fishpepper.de #")
    print("########################################")
    print("")

    efm8loader = EFM8Loader(args.port, args.baudrate, debug=args.verbose)

    if (args.identify):
        efm8loader.identify_chip()
    elif (args.write):
        efm8loader.upload(args.write)
    elif (args.read):
        efm8loader.download(args.read)
    elif (args.reset):
        efm8loader.send_reset()
    else:
        argp.print_help()
        sys.exit(1)

    print()
    sys.exit(0)
