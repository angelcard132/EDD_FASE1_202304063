unit arbol_avl;

interface

type
  PCorreoAVL = ^TCorreoAVL;
  TCorreoAVL = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    altura: Integer;
    izquierdo, derecho: PCorreoAVL;
  end;

procedure Inicializar(var raiz: PCorreoAVL);
function Altura(n: PCorreoAVL): Integer;
function Insertar(var raiz: PCorreoAVL; id: Integer; remitente, destinatario, asunto, mensaje: String): PCorreoAVL;
procedure InOrden(n: PCorreoAVL);

implementation

function Max(a, b: Integer): Integer;
begin
  if a > b then
    Max := a
  else
    Max := b;
end;

function Altura(n: PCorreoAVL): Integer;
begin
  if n = nil then
    Altura := 0
  else
    Altura := n^.altura;
end;

function CrearNodo(id: Integer; remitente, destinatario, asunto, mensaje: String): PCorreoAVL;
var
  nuevo: PCorreoAVL;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := destinatario;
  nuevo^.asunto := asunto;
  nuevo^.mensaje := mensaje;
  nuevo^.izquierdo := nil;
  nuevo^.derecho := nil;
  nuevo^.altura := 1;
  CrearNodo := nuevo;
end;

function RotarDerecha(y: PCorreoAVL): PCorreoAVL;
var
  x, T2: PCorreoAVL;
begin
  x := y^.izquierdo;
  T2 := x^.derecho;

  x^.derecho := y;
  y^.izquierdo := T2;

  y^.altura := Max(Altura(y^.izquierdo), Altura(y^.derecho)) + 1;
  x^.altura := Max(Altura(x^.izquierdo), Altura(x^.derecho)) + 1;

  RotarDerecha := x;
end;

function RotarIzquierda(x: PCorreoAVL): PCorreoAVL;
var
  y, T2: PCorreoAVL;
begin
  y := x^.derecho;
  T2 := y^.izquierdo;

  y^.izquierdo := x;
  x^.derecho := T2;

  x^.altura := Max(Altura(x^.izquierdo), Altura(x^.derecho)) + 1;
  y^.altura := Max(Altura(y^.izquierdo), Altura(y^.derecho)) + 1;

  RotarIzquierda := y;
end;

function Balance(n: PCorreoAVL): Integer;
begin
  if n = nil then
    Balance := 0
  else
    Balance := Altura(n^.izquierdo) - Altura(n^.derecho);
end;

function Insertar(var raiz: PCorreoAVL; id: Integer; remitente, destinatario, asunto, mensaje: String): PCorreoAVL;
var
  balanceFactor: Integer; // renombrada para evitar colisión con la función Balance
begin
  if raiz = nil then
  begin
    raiz := CrearNodo(id, remitente, destinatario, asunto, mensaje);
    Insertar := raiz;
    Exit;
  end;

  if id < raiz^.id then
    raiz^.izquierdo := Insertar(raiz^.izquierdo, id, remitente, destinatario, asunto, mensaje)
  else if id > raiz^.id then
    raiz^.derecho := Insertar(raiz^.derecho, id, remitente, destinatario, asunto, mensaje)
  else
  begin
    Insertar := raiz; // No insertar duplicados
    Exit;
  end;

  raiz^.altura := 1 + Max(Altura(raiz^.izquierdo), Altura(raiz^.derecho));
  balanceFactor := Balance(raiz);

  { === Rotaciones === }

  // Caso Izquierda - Izquierda
  if (balanceFactor > 1) and (id < raiz^.izquierdo^.id) then
  begin
    raiz := RotarDerecha(raiz);
  end;

  // Caso Derecha - Derecha
  if (balanceFactor < -1) and (id > raiz^.derecho^.id) then
  begin
    raiz := RotarIzquierda(raiz);
  end;

  // Caso Izquierda - Derecha
  if (balanceFactor > 1) and (id > raiz^.izquierdo^.id) then
  begin
    raiz^.izquierdo := RotarIzquierda(raiz^.izquierdo);
    raiz := RotarDerecha(raiz);
  end;

  // Caso Derecha - Izquierda
  if (balanceFactor < -1) and (id < raiz^.derecho^.id) then
  begin
    raiz^.derecho := RotarDerecha(raiz^.derecho);
    raiz := RotarIzquierda(raiz);
  end;

  Insertar := raiz;
end;



procedure InOrden(n: PCorreoAVL);
begin
  if n <> nil then
  begin
    InOrden(n^.izquierdo);
    WriteLn('ID: ', n^.id, ' | Asunto: ', n^.asunto, ' | De: ', n^.remitente, ' -> ', n^.destinatario);
    InOrden(n^.derecho);
  end;
end;

procedure Inicializar(var raiz: PCorreoAVL);
begin
  raiz := nil;
end;

end.
