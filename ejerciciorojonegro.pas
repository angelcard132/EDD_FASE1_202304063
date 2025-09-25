program ejerciciorojonegro;

uses crt;

type
  Color = (Rojo, Negro);

  PNode = ^TNode;
  TNode = record
    dato: Integer;
    color: Color;
    izquierdo, derecho, padre: PNode;
  end;

var
  raiz: PNode = nil;

// Función para crear un nuevo nodo
function NuevoNodo(valor: Integer): PNode;
var
  nodo: PNode;
begin
  New(nodo);
  nodo^.dato := valor;
  nodo^.color := Rojo; // Siempre se inserta rojo primero
  nodo^.izquierdo := nil;
  nodo^.derecho := nil;
  nodo^.padre := nil;
  NuevoNodo := nodo; // <-- En Pascal clásico se usa el nombre de la función
end;

// Rotación izquierda
procedure RotarIzquierda(var raiz: PNode; x: PNode);
var
  y: PNode;
begin
  y := x^.derecho;
  x^.derecho := y^.izquierdo;
  if y^.izquierdo <> nil then
    y^.izquierdo^.padre := x;
  y^.padre := x^.padre;
  if x^.padre = nil then
    raiz := y
  else if x = x^.padre^.izquierdo then
    x^.padre^.izquierdo := y
  else
    x^.padre^.derecho := y;
  y^.izquierdo := x;
  x^.padre := y;
end;

// Rotación derecha
procedure RotarDerecha(var raiz: PNode; x: PNode);
var
  y: PNode;
begin
  y := x^.izquierdo;
  x^.izquierdo := y^.derecho;
  if y^.derecho <> nil then
    y^.derecho^.padre := x;
  y^.padre := x^.padre;
  if x^.padre = nil then
    raiz := y
  else if x = x^.padre^.derecho then
    x^.padre^.derecho := y
  else
    x^.padre^.izquierdo := y;
  y^.derecho := x;
  x^.padre := y;
end;

// Balanceo después de la inserción
procedure BalancearInsercion(var raiz: PNode; z: PNode);
var
  y: PNode;
begin
  while (z^.padre <> nil) and (z^.padre^.color = Rojo) do
  begin
    if z^.padre = z^.padre^.padre^.izquierdo then
    begin
      y := z^.padre^.padre^.derecho;
      if (y <> nil) and (y^.color = Rojo) then
      begin
        z^.padre^.color := Negro;
        y^.color := Negro;
        z^.padre^.padre^.color := Rojo;
        z := z^.padre^.padre;
      end
      else
      begin
        if z = z^.padre^.derecho then
        begin
          z := z^.padre;
          RotarIzquierda(raiz, z);
        end;
        z^.padre^.color := Negro;
        z^.padre^.padre^.color := Rojo;
        RotarDerecha(raiz, z^.padre^.padre);
      end;
    end
    else
    begin
      y := z^.padre^.padre^.izquierdo;
      if (y <> nil) and (y^.color = Rojo) then
      begin
        z^.padre^.color := Negro;
        y^.color := Negro;
        z^.padre^.padre^.color := Rojo;
        z := z^.padre^.padre;
      end
      else
      begin
        if z = z^.padre^.izquierdo then
        begin
          z := z^.padre;
          RotarDerecha(raiz, z);
        end;
        z^.padre^.color := Negro;
        z^.padre^.padre^.color := Rojo;
        RotarIzquierda(raiz, z^.padre^.padre);
      end;
    end;
  end;
  raiz^.color := Negro;
end;

// Inserción en el árbol Rojo-Negro
procedure Insertar(var raiz: PNode; valor: Integer);
var
  z, y, x: PNode;
begin
  z := NuevoNodo(valor);
  y := nil;
  x := raiz;
  while x <> nil do
  begin
    y := x;
    if z^.dato < x^.dato then
      x := x^.izquierdo
    else
      x := x^.derecho;
  end;
  z^.padre := y;
  if y = nil then
    raiz := z
  else if z^.dato < y^.dato then
    y^.izquierdo := z
  else
    y^.derecho := z;
  BalancearInsercion(raiz, z);
end;

// Mostrar el árbol en consola (inorden)
procedure MostrarArbol(nodo: PNode);
begin
  if nodo <> nil then
  begin
    MostrarArbol(nodo^.izquierdo);
    Write('Dato: ', nodo^.dato);
    if nodo^.color = Rojo then
      Write(' (Rojo)')
    else
      Write(' (Negro)');
    if (nodo^.izquierdo = nil) and (nodo^.derecho = nil) then
      Write(' - Hoja');
    Writeln;
    MostrarArbol(nodo^.derecho);
  end;
end;

// Programa principal
begin
  clrscr;
  Insertar(raiz, 10);
  Insertar(raiz, 20);
  Insertar(raiz, 30);
  Insertar(raiz, 15);
  Insertar(raiz, 25);
  Insertar(raiz, 5);
  Insertar(raiz, 1);

  Writeln('Árbol Rojo-Negro (Inorden):');
  MostrarArbol(raiz);

  Readln;
end.
