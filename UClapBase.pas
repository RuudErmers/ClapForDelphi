unit UClapBase;

interface

uses Forms,  Classes;

type PSingle           = ^single;
     PPSingle          = ^PSingle;
     PDouble           = ^double;
     PPDouble          = ^PDouble;

type
     TClapBase = TComponent;
     TClapInstrumentClass = class of TClapBase;
     TClapInstrumentInfo =  record
                              ClapId,ClapName,vendor,url,manual_url,support_url,version,description:string;
                              clapInstrument  : TClapInstrumentClass;
                              clapEditor :  TFormClass;
                              isSynth,softMidiThru:boolean;
                            end;

implementation

end.


