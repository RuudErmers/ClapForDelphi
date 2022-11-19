# ClapForDelphi
Clap framework for Delphi

In the past I created a little framework to create VST2, VST3 and FruityPlug instruments.
See here: https://github.com/RuudErmers/RMSVST3

Now it is time to move on to CLAP: I don’t think anyone still uses FruityPlugs and since Steinberg forced me to delete support for VST2 it is a good time to ditch support for VST3 as well.  

There are two main class: TClapInstrumentBase and TClapInstrument.

- TClapInstrumentBase creates a Class which makes it easy to create a plugin without knowing the internals of Clap. You can use this for your development, or use TClapInstrument:
 
- TClapInstrument is a small layer above TClapInstrumentBase which allready implements a few things needed: Parameters, Midi Handling, State, Editor handling.
 
TClapInstrument is almost fully compatible with TVSTInstrument in the past. Only a few renames are necessary.

As an example there is TmyClap which is almost the same as the previous TmyVstPlugin. Only a few renames, mostly replacing ‘vst’ with ‘clap’ ! 

This is a preliminary version. If you have comments/bugs please let me know! 
