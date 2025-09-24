unit matrizdispersa;

interface

type
  PRelacion = ^TRelacion;
  TRelacion = record
    remitente: String;
    destinatario: String;
    cantidad: Integer;
    derecha, abajo: PRelacion;
  end;

  PMatriz = ^TMatriz;
  TMatriz = record
    cabeza: PRelacion;
  end;

procedure InicializarMatriz(var matriz: TMatriz);
procedure InsertarRelacion(var matriz: TMatriz; remitente, destinatario: String);
procedure MostrarMatriz(var matriz: TMatriz);

implementation

procedure InicializarMatriz(var matriz: TMatriz);
begin
  matriz.cabeza := nil;
end;

procedure InsertarRelacion(var matriz: TMatriz; remitente, destinatario: String);
var
  actual, nuevo: PRelacion;
begin
  actual := matriz.cabeza;
  while (actual <> nil) do
  begin
    if (actual^.remitente = remitente) and (actual^.destinatario = destinatario) then
    begin
      Inc(actual^.cantidad);
      Exit;
    end;
    actual := actual^.derecha;
  end;

  New(nuevo);
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.cantidad := 1;
  nuevo^.derecha := matriz.cabeza;
  nuevo^.abajo := nil;
  matriz.cabeza := nuevo;
end;

procedure MostrarMatriz(var matriz: TMatriz);
var
  actual: PRelacion;
begin
  actual := matriz.cabeza;
  while actual <> nil do
  begin
    WriteLn(actual^.remitente, ' -> ', actual^.destinatario, ' : ', actual^.cantidad);
    actual := actual^.derecha;
  end;
end;

end.
