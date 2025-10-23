unit merkle_tree;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, md5;

type
  PCorreoPrivado = ^TCorreoPrivado;
  TCorreoPrivado = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    fechaCreacion: String;
    hash: String;
  end;

  PNodoMerkle = ^TNodoMerkle;
  TNodoMerkle = record
    hash: String;
    correo: PCorreoPrivado; // Solo en hojas
    izquierdo: PNodoMerkle;
    derecho: PNodoMerkle;
    esHoja: Boolean;
  end;

  TArbolMerkle = record
    raiz: PNodoMerkle;
    totalCorreos: Integer;
  end;

  // ✅ DECLARAR TIPO DE CALLBACK CORRECTAMENTE
  TMerkleCallback = procedure(correo: PCorreoPrivado; data: Pointer);

procedure InicializarArbolMerkle(var arbol: TArbolMerkle);
function InsertarCorreoPrivado(var arbol: TArbolMerkle; id: Integer; const remitente, destinatario, asunto, mensaje: String): Boolean;
function BuscarCorreoPrivado(arbol: TArbolMerkle; id: Integer): PCorreoPrivado;
function EliminarCorreoPrivado(var arbol: TArbolMerkle; id: Integer): Boolean;
procedure MostrarArbolMerkle(arbol: TArbolMerkle);

// Recorridos del árbol
procedure PreOrdenMerkle(nodo: PNodoMerkle);
procedure InOrdenMerkle(nodo: PNodoMerkle);
procedure PostOrdenMerkle(nodo: PNodoMerkle);

// ✅ CORREGIR DECLARACIÓN DEL PROCEDIMIENTO
procedure RecorridoPersonalizadoMerkle(nodo: PNodoMerkle; callback: TMerkleCallback; data: Pointer);
function ContarCorreosPrivadosDelUsuario(arbol: TArbolMerkle; const emailUsuario: String): Integer;

// Función para generar reporte DOT
procedure GenerarReporteMerkle(arbol: TArbolMerkle; const rutaDot: String);

// Liberación de memoria
procedure LiberarArbolMerkle(var arbol: TArbolMerkle);

implementation

// Función para calcular hash MD5
function CalcularHash(const texto: String): String;
begin
  Result := MD5Print(MD5String(texto));
end;

// Función para calcular hash de un correo
function CalcularHashCorreo(const correo: TCorreoPrivado): String;
var
  datos: String;
begin
  datos := IntToStr(correo.id) + correo.remitente + correo.destinatario + correo.asunto + correo.mensaje;
  Result := CalcularHash(datos);
end;

// Función para calcular hash de dos nodos hijos
function CalcularHashNodo(const hashIzq, hashDer: String): String;
begin
  Result := CalcularHash(hashIzq + hashDer);
end;

procedure InicializarArbolMerkle(var arbol: TArbolMerkle);
begin
  arbol.raiz := nil;
  arbol.totalCorreos := 0;
  WriteLn('🌳 Árbol de Merkle inicializado para correos privados');
end;

function CrearNodoHoja(id: Integer; const remitente, destinatario, asunto, mensaje: String): PNodoMerkle;
var
  nodo: PNodoMerkle;
  correo: PCorreoPrivado;
begin
  New(nodo);
  New(correo);
  
  // Llenar datos del correo
  correo^.id := id;
  correo^.remitente := remitente;
  correo^.destinatario := destinatario;
  correo^.asunto := asunto;
  correo^.mensaje := mensaje;
  correo^.fechaCreacion := FormatDateTime('dd/mm/yyyy hh:nn:ss', Now);
  correo^.hash := CalcularHashCorreo(correo^);
  
  // Configurar nodo
  nodo^.hash := correo^.hash;
  nodo^.correo := correo;
  nodo^.izquierdo := nil;
  nodo^.derecho := nil;
  nodo^.esHoja := True;
  
  Result := nodo;
end;

function CrearNodoInterno(izq, der: PNodoMerkle): PNodoMerkle;
var
  nodo: PNodoMerkle;
  hashIzq, hashDer: String;
begin
  New(nodo);
  
  // Obtener hashes de los hijos
  if izq <> nil then 
    hashIzq := izq^.hash 
  else 
    hashIzq := '';
    
  if der <> nil then 
    hashDer := der^.hash 
  else 
    hashDer := '';
  
  nodo^.hash := CalcularHashNodo(hashIzq, hashDer);
  nodo^.correo := nil;
  nodo^.izquierdo := izq;
  nodo^.derecho := der;
  nodo^.esHoja := False;
  
  Result := nodo;
end;

function InsertarRecursivo(nodo: PNodoMerkle; nuevoNodo: PNodoMerkle): PNodoMerkle;
var
  hashIzq, hashDer: String;
begin
  if nodo = nil then
    Result := nuevoNodo
  else if nodo^.esHoja then
  begin
    // Si es hoja, crear nodo interno con la hoja actual y el nuevo
    Result := CrearNodoInterno(nodo, nuevoNodo);
  end
  else
  begin
    // Si es nodo interno, insertar en el subárbol derecho por simplicidad
    nodo^.derecho := InsertarRecursivo(nodo^.derecho, nuevoNodo);
    
    // ✅ RECALCULAR HASH DEL NODO - CORREGIR SINTAXIS
    if nodo^.izquierdo <> nil then 
      hashIzq := nodo^.izquierdo^.hash 
    else 
      hashIzq := '';
      
    if nodo^.derecho <> nil then 
      hashDer := nodo^.derecho^.hash 
    else 
      hashDer := '';
      
    nodo^.hash := CalcularHashNodo(hashIzq, hashDer);
    Result := nodo;
  end;
end;

function InsertarCorreoPrivado(var arbol: TArbolMerkle; id: Integer; const remitente, destinatario, asunto, mensaje: String): Boolean;
var
  nuevoNodo: PNodoMerkle;
begin
  Result := False;
  
  try
    nuevoNodo := CrearNodoHoja(id, remitente, destinatario, asunto, mensaje);
    arbol.raiz := InsertarRecursivo(arbol.raiz, nuevoNodo);
    Inc(arbol.totalCorreos);
    
    WriteLn('🔒 Correo privado insertado en Merkle Tree - ID: ', id, ' Hash: ', nuevoNodo^.hash);
    Result := True;
  except
    on E: Exception do
      WriteLn('❌ Error insertando correo privado: ', E.Message);
  end;
end;

function BuscarRecursivo(nodo: PNodoMerkle; id: Integer): PCorreoPrivado;
begin
  if nodo = nil then
    Result := nil
  else if nodo^.esHoja then
  begin
    if (nodo^.correo <> nil) and (nodo^.correo^.id = id) then
      Result := nodo^.correo
    else
      Result := nil;
  end
  else
  begin
    Result := BuscarRecursivo(nodo^.izquierdo, id);
    if Result = nil then
      Result := BuscarRecursivo(nodo^.derecho, id);
  end;
end;

function BuscarCorreoPrivado(arbol: TArbolMerkle; id: Integer): PCorreoPrivado;
begin
  Result := BuscarRecursivo(arbol.raiz, id);
end;

function EliminarCorreoPrivado(var arbol: TArbolMerkle; id: Integer): Boolean;
begin
  // Por simplicidad, marcamos como eliminado en lugar de restructurar el árbol
  Result := False;
  WriteLn('⚠️ Eliminación en Merkle Tree: funcionalidad simplificada');
  // En una implementación completa, se reconstruiría el árbol
end;

procedure PreOrdenMerkle(nodo: PNodoMerkle);
begin
  if nodo = nil then Exit;
  
  if nodo^.esHoja and (nodo^.correo <> nil) then
    WriteLn('🔒 Hoja - ID: ', nodo^.correo^.id, ' Hash: ', nodo^.hash)
  else
    WriteLn('🌳 Nodo Interno - Hash: ', nodo^.hash);
  
  PreOrdenMerkle(nodo^.izquierdo);
  PreOrdenMerkle(nodo^.derecho);
end;

procedure InOrdenMerkle(nodo: PNodoMerkle);
begin
  if nodo = nil then Exit;
  
  InOrdenMerkle(nodo^.izquierdo);
  
  if nodo^.esHoja and (nodo^.correo <> nil) then
    WriteLn('🔒 Hoja - ID: ', nodo^.correo^.id, ' Asunto: ', nodo^.correo^.asunto)
  else
    WriteLn('🌳 Nodo Interno - Hash: ', Copy(nodo^.hash, 1, 8), '...');
  
  InOrdenMerkle(nodo^.derecho);
end;

procedure PostOrdenMerkle(nodo: PNodoMerkle);
begin
  if nodo = nil then Exit;
  
  PostOrdenMerkle(nodo^.izquierdo);
  PostOrdenMerkle(nodo^.derecho);
  
  if nodo^.esHoja and (nodo^.correo <> nil) then
    WriteLn('🔒 Hoja - ID: ', nodo^.correo^.id, ' De: ', nodo^.correo^.remitente)
  else
    WriteLn('🌳 Nodo Interno - Hash: ', Copy(nodo^.hash, 1, 8), '...');
end;

procedure RecorridoPersonalizadoMerkle(nodo: PNodoMerkle; callback: TMerkleCallback; data: Pointer);
begin
  if nodo = nil then Exit;
  
  if nodo^.esHoja and (nodo^.correo <> nil) then
    callback(nodo^.correo, data)
  else
  begin
    RecorridoPersonalizadoMerkle(nodo^.izquierdo, callback, data);
    RecorridoPersonalizadoMerkle(nodo^.derecho, callback, data);
  end;
end;

function ContarCorreosPrivadosDelUsuario(arbol: TArbolMerkle; const emailUsuario: String): Integer;

  function ContarRecursivo(nodo: PNodoMerkle): Integer;
  begin
    if nodo = nil then
      Result := 0
    else if nodo^.esHoja and (nodo^.correo <> nil) then
    begin
      if (nodo^.correo^.remitente = emailUsuario) or (nodo^.correo^.destinatario = emailUsuario) then
        Result := 1
      else
        Result := 0;
    end
    else
      Result := ContarRecursivo(nodo^.izquierdo) + ContarRecursivo(nodo^.derecho);
  end;

begin
  Result := ContarRecursivo(arbol.raiz);
end;

procedure MostrarArbolMerkle(arbol: TArbolMerkle);
begin
  WriteLn('🌳 ÁRBOL DE MERKLE - CORREOS PRIVADOS');
  WriteLn('=====================================');
  WriteLn('Total correos: ', arbol.totalCorreos);
  if arbol.raiz <> nil then
    WriteLn('Hash raíz: ', arbol.raiz^.hash);
  WriteLn('=====================================');
end;

procedure GenerarNodosMerkleRecursivo(var f: Text; nodo: PNodoMerkle; var contador: Integer);
var
  nodoID: Integer;
  hashCorto: String;
  labelTexto: String;
begin
  if nodo = nil then Exit;
  
  Inc(contador);
  nodoID := contador;
  hashCorto := Copy(nodo^.hash, 1, 12); // Mostrar más caracteres del hash
  
  if nodo^.esHoja and (nodo^.correo <> nil) then
  begin
    // Nodo hoja con correo privado
    labelTexto := Format('🔒 CORREO PRIVADO\\nID: %d\\nDe: %s\\nPara: %s\\nAsunto: %s\\nFecha: %s\\nHash: %s',
                         [nodo^.correo^.id, 
                          Copy(nodo^.correo^.remitente, 1, 20),
                          Copy(nodo^.correo^.destinatario, 1, 20),
                          Copy(nodo^.correo^.asunto, 1, 30),
                          Copy(nodo^.correo^.fechaCreacion, 1, 16),
                          hashCorto]);
    
    WriteLn(f, Format('  nodo_%d [label="%s", fillcolor="#FFE4E1", shape="box", style="filled,rounded"];',
                     [nodoID, labelTexto]));
  end
  else
  begin
    // Nodo interno del Merkle Tree
    labelTexto := Format('🌳 NODO MERKLE\\nNivel: Interno\\nHash: %s\\nHijos: %s',
                         [hashCorto,
                          'L+R']);
    
    WriteLn(f, Format('  nodo_%d [label="%s", fillcolor="#E6F3FF", shape="diamond", style="filled"];',
                     [nodoID, labelTexto]));
  end;
  
  // Generar hijos y conexiones
  if nodo^.izquierdo <> nil then
  begin
    GenerarNodosMerkleRecursivo(f, nodo^.izquierdo, contador);
    WriteLn(f, Format('  nodo_%d -> nodo_%d [label="Izq", color="green", fontcolor="green", penwidth=2];', 
                     [nodoID, contador]));
  end;
  
  if nodo^.derecho <> nil then
  begin
    GenerarNodosMerkleRecursivo(f, nodo^.derecho, contador);
    WriteLn(f, Format('  nodo_%d -> nodo_%d [label="Der", color="blue", fontcolor="blue", penwidth=2];', 
                     [nodoID, contador]));
  end;
end;

procedure GenerarReporteMerkle(arbol: TArbolMerkle; const rutaDot: String);
var
  f: Text;
  contador: Integer;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph ArbolMerkle {');
    WriteLn(f, '  rankdir=TB;');
    WriteLn(f, '  node [style=filled, fontname="Arial", fontsize=9];');
    WriteLn(f, '  edge [fontname="Arial", fontsize=8];');
    WriteLn(f, '  label="🔒 ÁRBOL DE MERKLE - CORREOS PRIVADOS\\nEstructura Criptográfica para Integridad de Datos\\nTotal Correos: ' + IntToStr(arbol.totalCorreos) + '"; labelloc=t; fontsize=14; fontcolor=purple;');
    WriteLn(f, '');
    
    // Leyenda mejorada
    WriteLn(f, '  subgraph cluster_leyenda {');
    WriteLn(f, '    label="🔐 Leyenda del Merkle Tree";');
    WriteLn(f, '    style=filled;');
    WriteLn(f, '    fillcolor="#F0F8FF";');
    WriteLn(f, '    fontcolor=navy;');
    WriteLn(f, '    leyenda_hoja [label="🔒 Correo Privado\\n(Hoja con datos)", fillcolor="#FFE4E1", shape="box", style="filled,rounded"];');
    WriteLn(f, '    leyenda_nodo [label="🌳 Nodo Merkle\\n(Hash combinado)", fillcolor="#E6F3FF", shape="diamond"];');
    WriteLn(f, '    leyenda_izq [label="Hijo Izquierdo", color="green", style="bold"];');
    WriteLn(f, '    leyenda_der [label="Hijo Derecho", color="blue", style="bold"];');
    WriteLn(f, '    leyenda_info [label="📋 Propiedades:\\n• Hash = MD5(datos)\\n• Integridad garantizada\\n• Detección de cambios\\n• Verificación rápida", shape="note", fillcolor="#FFFFCC"];');
    WriteLn(f, '  }');
    WriteLn(f, '');
    
    if arbol.raiz = nil then
    begin
      WriteLn(f, '  vacio [label="🔒 Árbol Merkle Vacío\\n\\nNo hay correos privados\\n\\nPara agregar correos:\\n1. Ve a tu bandeja de entrada\\n2. Selecciona un correo\\n3. Haz clic en \\\"🔒 A Privados\\\"", fillcolor="#F0F0F0", fontcolor="gray", shape="box", style="filled,rounded"];');
    end
    else
    begin
      contador := 0;
      GenerarNodosMerkleRecursivo(f, arbol.raiz, contador);
      
      // Información adicional del árbol
      WriteLn(f, '');
      WriteLn(f, '  subgraph cluster_info {');
      WriteLn(f, '    label="ℹ️ Información del Árbol";');
      WriteLn(f, '    style=filled;');
      WriteLn(f, '    fillcolor="#F5F5DC";');
      WriteLn(f, '    info_total [label="📊 Total Correos: ' + IntToStr(arbol.totalCorreos) + '", shape="note"];');
      WriteLn(f, '    info_hash [label="🔐 Hash Raíz:\\n' + Copy(arbol.raiz^.hash, 1, 16) + '...", shape="note"];');
      WriteLn(f, '    info_estructura [label="🌳 Estructura:\\nCada nodo = Hash(hijo_izq + hijo_der)\\nHojas = Hash(datos_correo)", shape="note"];');
      WriteLn(f, '  }');
      
      // Conectar información con la raíz si existe
      if contador > 0 then
        WriteLn(f, '  nodo_1 -> info_hash [style="dotted", color="gray", arrowhead="none"];');
    end;
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
  
  WriteLn('🔒 Reporte visual del Merkle Tree generado: ', rutaDot);
  WriteLn('📊 Nodos generados en el gráfico: ', contador);
  WriteLn('🌳 Hash raíz: ', arbol.raiz^.hash);
end;

procedure LiberarNodoMerkle(nodo: PNodoMerkle);
begin
  if nodo = nil then Exit;
  
  LiberarNodoMerkle(nodo^.izquierdo);
  LiberarNodoMerkle(nodo^.derecho);
  
  if nodo^.correo <> nil then
    Dispose(nodo^.correo);
  
  Dispose(nodo);
end;

procedure LiberarArbolMerkle(var arbol: TArbolMerkle);
begin
  LiberarNodoMerkle(arbol.raiz);
  arbol.raiz := nil;
  arbol.totalCorreos := 0;
  WriteLn('🔒 Árbol de Merkle liberado');
end;

end.
