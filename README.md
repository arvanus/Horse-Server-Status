# horse-exception-logger
Middleware for showing active routes being processed at the time in HORSE

### For install in your project using [boss](https://github.com/HashLoad/boss):
``` sh
$ boss install arvanus/Horse-Server-Status
```

### Sample

Sample Horse Server Status, not tested under Lazarus
```

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
```
