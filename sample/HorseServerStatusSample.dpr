program HorseServerStatusSample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Classes,
  Horse,
  Horse.Jhonson,
  Horse.ServerStatus;

begin
  try
 THorse
    .Use(Jhonson)
    .Use(ServerStatus);

  THorse.Get('/server-status',  ShowServerStatus);
  THorse.Get('/delay',  procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
  begin
    TThread.Sleep(5000);
    Res.Send('OK');
  end);
  THorse.Get('/delay/:bla',  procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
  begin
    TThread.Sleep(5000);
    Res.Send('OK');
  end);


  THorse.Listen(9000);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
