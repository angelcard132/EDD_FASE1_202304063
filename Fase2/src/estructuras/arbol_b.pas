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

  // Callback para recorridos personalizados
  TCallbackFavorito = procedure(correo: TCorreoB; data: Pointer);

procedure Inicializar(var raiz: PNodoB);
procedure Insertar(var raiz: PNodoB; correo: TCorreoB);
function Buscar(raiz: PNodoB; id: Integer): PCorreoB;
function Eliminar(var raiz: PNodoB; id: Integer): Boolean;
procedure Mostrar(var nodo: PNodoB; nivel: Integer);
procedure RecorridoInOrden(nodo: PNodoB; callback: TCallbackFavorito; data: Pointer);
function ContarCorreos(nodo: PNodoB): Integer;
procedure LiberarArbol(var raiz: PNodoB);

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

function BuscarEnNodo(nodo: PNodoB; id: Integer): PCorreoB;
var
  i: Integer;
begin
  BuscarEnNodo := nil;
  if nodo = nil then Exit;
  
  for i := 1 to nodo^.n do
  begin
    if nodo^.claves[i].id = id then
    begin
      BuscarEnNodo := @nodo^.claves[i];
      Exit;
    end;
  end;
end;

function Buscar(raiz: PNodoB; id: Integer): PCorreoB;
var
  i: Integer;
  encontrado: PCorreoB;
begin
  Buscar := nil;
  if raiz = nil then Exit;
  
  // Buscar en el nodo actual
  encontrado := BuscarEnNodo(raiz, id);
  if encontrado <> nil then
  begin
    Buscar := encontrado;
    Exit;
  end;
  
  // Si no es hoja, buscar en hijos apropiados
  if not raiz^.hoja then
  begin
    i := 1;
    while (i <= raiz^.n) and (id > raiz^.claves[i].id) do
      Inc(i);
    
    Buscar := Buscar(raiz^.hijos[i-1], id);
  end;
end;

function EliminarDeNodo(var nodo: PNodoB; id: Integer): Boolean;
var
  i, j: Integer;
begin
  EliminarDeNodo := False;
  if nodo = nil then Exit;
  
  for i := 1 to nodo^.n do
  begin
    if nodo^.claves[i].id = id then
    begin
      // Mover elementos hacia la izquierda
      for j := i to nodo^.n - 1 do
        nodo^.claves[j] := nodo^.claves[j + 1];
      Dec(nodo^.n);
      EliminarDeNodo := True;
      Exit;
    end;
  end;
end;

function Eliminar(var raiz: PNodoB; id: Integer): Boolean;
var
  i: Integer;
begin
  Eliminar := False;
  if raiz = nil then Exit;
  
  // Implementación simplificada: solo eliminar de hojas
  if raiz^.hoja then
  begin
    Eliminar := EliminarDeNodo(raiz, id);
    if raiz^.n = 0 then
    begin
      Dispose(raiz);
      raiz := nil;
    end;
  end
  else
  begin
    // Para nodos internos, buscar en hijos
    i := 1;
    while (i <= raiz^.n) and (id > raiz^.claves[i].id) do
      Inc(i);
    
    Eliminar := Eliminar(raiz^.hijos[i-1], id);
  end;
end;

procedure RecorridoInOrden(nodo: PNodoB; callback: TCallbackFavorito; data: Pointer);
var
  i: Integer;
begin
  if nodo = nil then Exit;
  
  if nodo^.hoja then
  begin
    // En hojas, procesar todas las claves
    for i := 1 to nodo^.n do
      callback(nodo^.claves[i], data);
  end
  else
  begin
    // En nodos internos, intercalar hijos y claves
    for i := 1 to nodo^.n do
    begin
      RecorridoInOrden(nodo^.hijos[i-1], callback, data);
      callback(nodo^.claves[i], data);
    end;
    RecorridoInOrden(nodo^.hijos[nodo^.n], callback, data);
  end;
end;

function ContarCorreos(nodo: PNodoB): Integer;
var
  i: Integer;
begin
  ContarCorreos := 0;
  if nodo = nil then Exit;
  
  ContarCorreos := nodo^.n;
  
  if not nodo^.hoja then
    for i := 0 to nodo^.n do
      ContarCorreos := ContarCorreos + ContarCorreos(nodo^.hijos[i]);
end;

procedure LiberarArbol(var raiz: PNodoB);
var
  i: Integer;
begin
  if raiz = nil then Exit;
  
  if not raiz^.hoja then
    for i := 0 to raiz^.n do
      LiberarArbol(raiz^.hijos[i]);
  
  Dispose(raiz);
  raiz := nil;
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
