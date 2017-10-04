# We're going to generate a lookup table to map ADC values
# (0-1023) to phase-increments. Each octave will be split
# into 128 steps, giving a range of 8 octaves.

# PWM rate is 250kHz, we'd like an integer-ratio of this
# for our sample rate. Also, bear in mind that we are
# generating 2 oscillators, so the interrupt will actually
# be running at twice this rate...
SRATE=22500
WTSIZE=1024

# root frequency is that of A0 (according to Dodge and Jerse pg.37)
ROOT=27.50

# The indexer only has 6 fractional bits, so we may as well
# just match that.
FRACBITS = 6

# 128 steps per octave means that the 10 bit ADC covers 8 octaves
OCTSTEPS=128
OCTS=(1024/128)

File.open("calc.h",'w') do |f|
  f.puts "#include \"arduino.h\"\n"
  f.puts "#define SRATE    (#{SRATE}L)"
  f.puts "#define WTSIZE   (#{WTSIZE}L)"
  f.puts "#define FRACBITS (#{FRACBITS}L)"
  f.puts "extern const uint16_t octaveLookup[1024];"
  f.puts "extern const uint8_t sine[WTSIZE];"
  f.puts "extern const uint8_t ramp[WTSIZE];"
  f.puts
end

# Let's calculate a single octave's worth of increments,
# subsequent octaves are simply power-of-2 multiples of those
# base octave values

File.open("calc.ino",'w') do |f|
  f.puts "#include \"calc.h\""
  f.puts "const uint16_t octaveLookup[1024] PROGMEM = {"

  (0...1024).each do |n|
    freq = ROOT * (2.0**(n.to_f/OCTSTEPS))
    # Dodge & Jerse (pg.67) say that the sample increment is WTSIZE*(fo/fs)
    si = (WTSIZE * freq)/SRATE
    sifixed = ((WTSIZE << FRACBITS)* freq)/SRATE
    f.puts "  0x#{sifixed.to_i.to_s(16)}, // #{freq} [#{si}]"
  end
  f.puts "};\n"

  # generate a sine table.
  TWO_PI = 2 * Math::PI
  LINELENGTH = 16
  f.puts "// Wavetable/cycle length is #{WTSIZE} - here's a buffer for it:"
  f.puts "const uint8_t sine[WTSIZE] PROGMEM = {"
  f.print "  "
  (0...WTSIZE).each do |n|
    v = Math::sin(TWO_PI * n.to_f/WTSIZE.to_f)
    f.print "0x#{((v*127)+127).to_i.to_s(16)}, "
    if ((n % LINELENGTH) == (LINELENGTH-1))
      f.print "\n  "
    end
  end
  f.puts "};"
  f.puts "const uint8_t ramp[WTSIZE] PROGMEM = {"
  f.print "  "
  (0...WTSIZE).each do |n|
    f.print "0x#{(n/4).to_s(16)}, "
    if ((n % LINELENGTH) == (LINELENGTH-1))
      f.print "\n  "
    end
  end
  f.puts "};"
end