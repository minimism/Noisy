#include "calc.h"
#define NUM_ADCS (4)

// Base-timer is running at 8MHz
#define F_TIM (8000000L)

// Fixed value to start the ADC
// enable ADC, start conversion, prescaler = /32 gives us an ADC clock of 8MHz/32 (250kHz)
#define ADCSRAVAL ( _BV(ADEN) | _BV(ADSC) | _BV(ADPS2) | _BV(ADIE) )

// Remember(!) the input clock is 64MHz, therefore all rates
// are relative to that.
// let the preprocessor calculate the various register values 'coz
// they don't change after compile time
#if ((F_TIM/(SRATE)) < 255)
#define T1_MATCH ((F_TIM/(SRATE))-1)
#define T1_PRESCALE _BV(CS00)  //prescaler clk/1 (i.e. 8MHz)
#else
#define T1_MATCH (((F_TIM/8L)/(SRATE))-1)
#define T1_PRESCALE _BV(CS01)  //prescaler clk/8 (i.e. 1MHz)
#endif


#define OSCOUTREG (OCR1A)

const uint8_t     *wave;      // which wavetable will this oscillator use?
uint16_t          phase;      // The accumulated phase (distance through the wavetable)
uint16_t          pi;         // current phase increment (how much phase will increase per sample)

void setup()
{
  PLLCSR |= _BV(PLLE);                // Enable 64 MHz PLL
  delayMicroseconds(100);             // Stabilize
  while (!(PLLCSR & _BV(PLOCK)));     // Wait for it...
  PLLCSR |= _BV(PCKE);                // Timer1 source = PLL

  ///////////////////////////////////////////////
  // Set up Timer/Counter1 for 250kHz PWM output
  TCCR1 = 0;                  // stop the timer
  TCNT1 = 0;                  // zero the timer
  GTCCR = _BV(PSR1);          // reset the prescaler
  TCCR1 = _BV(PWM1A) | _BV(COM1A1) | _BV(COM1A0) | _BV(CS10);
  OCR1C = 255;
  OCR1A = 128;                // start with 50% duty cycle on the PWM
  pinMode(PB1, OUTPUT);       // PWM output pin


  wave = sine;
  ///////////////////////////////////////////////
  // Set up Timer/Counter0 for sample-rate ISR
  TCCR0B = 0;                 // stop the timer (no clock source)
  TCNT0 = 0;                  // zero the timer

  TCCR0A = _BV(WGM01);        // CTC Mode
  TCCR0B = T1_PRESCALE;
  OCR0A = T1_MATCH;           // calculated match value
  TIMSK |= _BV(OCIE0A);

  ///////////////////////////////////////////////
  // Set up the ADC
  // read from analogue on (chip pin 7)
  pinMode(A1, INPUT);
  // read from analogue on (chip pin 3)
  pinMode(A2, INPUT);
  DIDR0 = _BV(ADC1D) | _BV(ADC2D);  // disable digital pin attached to ADC 1 & 2
  ADMUX  = 0;                       // select the mux for ADC0
  //ADCSRA = ADCSRAVAL;             // enable the ADC, set prescaler and start a conversion

  pinMode(PB0, OUTPUT);       // signalling pin

  pi = 1;
}

#if 0
// See http://doitwireless.com/2014/06/26/8-bit-pseudo-random-number-generator/
uint8_t rnd()
{
  static uint8_t r = 0x23;
  uint8_t lsb = r & 1;
  r >>= 1;
  r ^= (-lsb) & 0xB8;
  return r;
}
#endif


#define DATAWHEEL (1)

void loop()
{
  static uint8_t adcNum=0;                // declared as static to limit variable scope
#ifdef DATAWHEEL
  static uint8_t dataWheel;
#endif
  uint16_t  adcVal = analogRead(adcNum);  // Get the next adc value
  switch(adcNum)
  {
    case 0: // reduced range ~ 512-1023
#ifdef DATAWHEEL
      if (adcVal > 768)   // i.e. push button
        wave = (dataWheel > 128) ? ramp : sine;
#endif
      break;
    case 1:
#ifdef DATAWHEEL
      // used by other functions via button push
      dataWheel = adcVal >> 2;
#endif
      break;
    case 2:
      break;
    case 3:
      pi = pgm_read_word(&octaveLookup[adcVal]);
      break;
  }
  

  // next time we're dealing with a different channel; calculate which one:
  adcNum++;
  adcNum %= NUM_ADCS;

  // Start the ADC off again, this time for the next oscillator
  // it turns out that simply setting the MUX to the ADC number (0-3)
  // will select that channel, as long as you don't want to set any other bits
  // in ADMUX of course. Still, that's simple to do if you need to.
  ADMUX  = adcNum;      // select the correct channel for the next conversion
  ADCSRA |= _BV(ADSC);  // ADCSRAVAL;
}

uint8_t state;
// deal with oscillator; straight-line code
ISR(TIM0_COMPA_vect)
{
  PORTB ^= 1;
  // increment the phase counter
  phase += pi;
  uint16_t p = (phase+HALF) >> FRACBITS;
  
  // look up the output-value based on the current phase counter (rounded)
  OSCOUTREG = pgm_read_byte(&wave[p]);
}

