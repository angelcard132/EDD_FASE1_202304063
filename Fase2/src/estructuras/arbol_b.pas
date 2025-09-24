unit arbol_b;

interface

const
  ORDEN = 5;
  MAX = ORDEN - 1;

type
  PCorreoB = ^TCorreoB;
  TCorreoB = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
  end;

  PNodoB = ^TNodoB;
  TNodoB = record
    n: Integer;
    claves: array[1..MAX] of TCorreoB;
    hijos: array[0..ORDEN] of PNodoB;
    hoja: Boolean;
  end;

procedure Inicializar(var raiz: PNodoB);
procedure Insertar(var raiz: PNodoB; correo: TCorreoB);
procedure Mostrar(var nodo: PNodoB; nivel: Integer);

implementation

procedure Inicializar(var raiz: PNodoB);
begin
  raiz := nil;
end;

function CrearNodo(hoja: Boolean): PNodoB;
var
  nuevo: PNodoB;
  i: Integer;
begin
  New(nuevo);
  nuevo^.n := 0;
  nuevo^.hoja := hoja;
  for i := 0 to ORDEN do
    nuevo^.hijos[i] := nil;
  CrearNodo := nuevo;
end;

procedure DividirHijo(x: PNodoB; i: Integer; y: PNodoB);
var
  z: PNodoB;
  j: Integer;
begin
  z := CrearNodo(y^.hoja);
  z^.n := 2;

  for j := 1 to 2 do
    z^.claves[j] := y^.claves[j+2];

  if not y^.hoja then
    for j := 0 to 2 do
      z^.hijos[j] := y^.hijos[j+3];

  y^.n := 2;

  for j := x^.n downto i+1 do
    x^.hijos[j+1] := x^.hijos[j];
  x^.hijos[i+1] := z;

  for j := x^.n downto i do
    x^.claves[j+1] := x^.claves[j];
  x^.claves[i] := y^.claves[3];

  Inc(x^.n);
end;

procedure InsertarNoLleno(x: PNodoB; correo: TCorreoB);
var
  i: Integer;
begin
  i := x^.n;
  if x^.hoja then
  begin
    while (i >= 1) and (correo.id < x^.claves[i].id) do
    begin
      x^.claves[i+1] := x^.claves[i];
      Dec(i);
    end;
    x^.claves[i+1] := correo;
    Inc(x^.n);
  end
  else
  begin
    while (i >= 1) and (correo.id < x^.claves[i].id) do
      Dec(i);
    Inc(i);
    if x^.hijos[i]^.n = MAX then
    begin
      DividirHijo(x, i, x^.hijos[i]);
      if correo.id > x^.claves[i].id then
        Inc(i);
    end;
    InsertarNoLleno(x^.hijos[i], correo);
  end;
end;

procedure Insertar(var raiz: PNodoB; correo: TCorreoB);
var
  s: PNodoB;
begin
  if raiz = nil then
  begin
    raiz := CrearNodo(True);
    raiz^.claves[1] := correo;
    raiz^.n := 1;
  end
  else
  begin
    if raiz^.n = MAX then
    begin
      s := CrearNodo(False);
      s^.hijos[0] := raiz;
      DividirHijo(s, 0, raiz);
      if correo.id > s^.claves[1].id then
        InsertarNoLleno(s^.hijos[1], correo)
      else
        InsertarNoLleno(s^.hijos[0], correo);
      raiz := s;
    end
    else
      InsertarNoLleno(raiz, correo);
  end;
end;

procedure Mostrar(var nodo: PNodoB; nivel: Integer);
var
  i: Integer;
begin
  if nodo <> nil then
  begin
    Write('Nivel ', nivel, ': ');
    for i := 1 to nodo^.n do
      Write('[', nodo^.claves[i].id, '-', nodo^.claves[i].asunto, '] ');
    WriteLn;
    if not nodo^.hoja then
      for i := 0 to nodo^.n do
        Mostrar(nodo^.hijos[i], nivel+1);
  end;
end;

end.
