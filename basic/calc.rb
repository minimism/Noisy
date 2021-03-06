# We're going to generate an octave's worth of increments.
# beginning by splitting an ocatve into steps

# PWM rate is 250kHz, we'd like an integer-ratio of this
# for our sample rate. Also, bear in mind that we are
# generating 2 oscillators, so the interrupt will actually
# be running at twice this rate...
SRATE=62500	# 250/4
WTSIZE=1024

# root frequency is that of A0 (according to Dodge and Jerse pg.37)
ROOT=27.50

# the integer part of the sample increments in the table are no
# larger than 1, so we could use 15 bits for the fraction
# however, the indexer only has 6 fractional bits, so we may as well
# just match that and save some space
FRACBITS = 6

# 128 steps per octave means that the 10 bit ADC covers 4 octaves
STEPS=128

File.open("calc.h",'w') do |f|
  f.puts "#include \"arduino.h\"\n"
  f.puts "#define SRATE (#{SRATE}L)"
  f.puts "#define WTSIZE (#{WTSIZE}L)"
  f.puts "#define OCTSTEPS (#{STEPS})"
  f.puts "#define NOTEMASK (0x#{(STEPS-1).to_s(16)})"
  f.puts "extern const uint8_t octaveLookup[#{STEPS}];"
  f.puts "extern const uint8_t wave[WTSIZE];"
  f.puts
end

File.open("calc.ino",'w') do |f|
  f.puts "#include \"calc.h\""
  f.puts "const uint8_t octaveLookup[#{STEPS}] PROGMEM = {"

  (0...STEPS).each do |n|
    freq = ROOT * (2.0**(n.to_f/STEPS))
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
  f.puts "const uint8_t wave[WTSIZE] PROGMEM = {"
  f.print "  "
  (0...WTSIZE).each do |n|
    v = Math::sin(TWO_PI * n.to_f/WTSIZE.to_f)
    f.print "0x#{((v*127)+127).to_i.to_s(16)}, "
    if ((n % LINELENGTH) == (LINELENGTH-1))
      f.print "\n  "
    end
  end
  f.puts "};"
end
