unit reports;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, cola2, listasimple2, arbol_avl, arbol_b, pila2, arbolbst, blockchain, merkle_tree;

// Función original
procedure GenerarGraficoBandeja(const emailDestino: String; var programados: TCola; const rutaDot: String);

// ✅ DECLARACIÓN ÚNICA de reporte Merkle Tree
procedure GenerarReporteMerklePrivados(const emailUsuario: String; var merklePrivados: TArbolMerkle; const rutaDot: String);

// ✅ DECLARACIÓN ÚNICA de reportes completos
procedure GenerarReportesCompletos(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain; var merklePrivados: TArbolMerkle);

// Otras funciones de reportes individuales
procedure GenerarReporteCorreosRecibidos(const emailUsuario: String; var programados: TCola; const rutaDot: String);
procedure GenerarReportePapelera(const emailUsuario: String; var papelera: TPila; const rutaDot: String);
procedure GenerarReporteProgramados(const emailUsuario: String; var programados: TCola; const rutaDot: String);
procedure GenerarReporteContactos(const emailUsuario: String; var usuarios: TListaSimple; const rutaDot: String);
procedure GenerarReporteFavoritos(const emailUsuario: String; var favoritos: PNodoB; const rutaDot: String);
procedure GenerarReporteBorradores(const emailUsuario: String; var borradores: PCorreoAVL; const rutaDot: String);
procedure GenerarReporteBSTComunidades(const rutaDot: String);

// Funciones auxiliares
procedure GenerarNodosBST(var f: Text; nodo: PNodoComunidadBST);
procedure GenerarNodosAVL(var f: Text; nodo: PCorreoAVL; const emailUsuario: String);
procedure GenerarNodosArbolB(var f: Text; nodo: PNodoB; const emailUsuario: String; var contadorNodos: Integer);

implementation

uses
  json_loader, comunidad;

function NormalizarEmail(const s: String): String;
var
  i: Integer;
  c: Char;
  lower: String;
begin
  lower := LowerCase(s);
  Result := '';
  for i := 1 to Length(lower) do
  begin
    c := lower[i];
    if (c = '–') or (c = '—') or (c = '−') or (c = '‑') then c := '-';
    if ((c >= 'a') and (c <= 'z')) or ((c >= '0') and (c <= '9')) or (c = '@') or (c = '.') or (c = '_') or (c = '-') then
      Result := Result + c;
  end;
end;

function SanearTexto(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if (Ord(c) >= 32) and (Ord(c) <= 126) then
      Result := Result + c
    else
      Result := Result + '?';
  end;
end;

function LimitarTexto(const s: String; maxLen: Integer): String;
begin
  if Length(s) > maxLen then
    Result := Copy(s, 1, maxLen) + '...'
  else
    Result := s;
end;

// Función auxiliar para reemplazar IfThen
function SeleccionarColor(condicion: Boolean; const colorTrue, colorFalse: String): String;
begin
  if condicion then
    Result := colorTrue
  else
    Result := colorFalse;
end;

procedure CrearDirectorioReportes(const emailUsuario: String; out rutaDir: String);
var
  nombreDirectorio: String;
begin
  nombreDirectorio := emailUsuario + '-reportes';
  rutaDir := ExtractFileDir(ExtractFileDir(ParamStr(0))) + '/graficos/' + nombreDirectorio;
  
  if not DirectoryExists(rutaDir) then
  begin
    CreateDir(rutaDir);
    WriteLn('📁 Directorio creado: ', rutaDir);
  end;
end;

function ContieneDestinatario(const emailCampo, emailBuscado: String): Boolean;
var
  emailNormalizado, buscadoNormalizado: String;
begin
  emailNormalizado := LowerCase(Trim(emailCampo));
  buscadoNormalizado := LowerCase(Trim(emailBuscado));
  
  if emailNormalizado = buscadoNormalizado then
    Result := True
  else
    Result := Pos(buscadoNormalizado, emailNormalizado) > 0;
end;

procedure GenerarGraficoBandeja(const emailDestino: String; var programados: TCola; const rutaDot: String);
var
  f: Text;
  actual: cola2.PCorreo;
  emailDestinoNorm, destNorm: String;
  idx: Integer;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph Bandeja {');
    WriteLn(f, '  rankdir=LR;');
    WriteLn(f, '  node [shape=box, style=filled, color="#4F81BD", fontname="Helvetica", fontsize=10, fillcolor="#DCE6F1"];');
    WriteLn(f, '  label="Bandeja de entrada de ' + SanearTexto(emailDestino) + '"; labelloc=t; fontsize=16;');

    emailDestinoNorm := NormalizarEmail(emailDestino);
    idx := 0;
    actual := programados.frente;
    while actual <> nil do
    begin
      destNorm := NormalizarEmail(String(actual^.destinatario));
      if destNorm = emailDestinoNorm then
      begin
        Inc(idx);
        WriteLn(f, Format('  correo_%d [label="ID: %d\nDe: %s\nAsunto: %s"];',
                 [idx, actual^.id, SanearTexto(String(actual^.remitente)), SanearTexto(String(actual^.asunto))]));
        if idx > 1 then
          WriteLn(f, Format('  correo_%d -> correo_%d;', [idx-1, idx]));
      end;
      actual := actual^.siguiente;
    end;

    if idx = 0 then
      WriteLn(f, '  vacio [label="Sin correos recibidos", fillcolor="#F2F2F2", color="#BFBFBF"];');

    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
end;

procedure GenerarReporteCorreosRecibidos(const emailUsuario: String; var programados: TCola; const rutaDot: String);
var
  f: Text;
  actual: cola2.PCorreo;
  emailNormalizado: String;
  idx: Integer;
  estado: String;
  colorFondo: String;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph CorreosRecibidos {');
    WriteLn(f, '  rankdir=TB;');
    WriteLn(f, '  node [shape=record, style=filled, fontname="Arial", fontsize=9];');
    WriteLn(f, '  label="📥 CORREOS RECIBIDOS - ' + SanearTexto(emailUsuario) + '"; labelloc=t; fontsize=14; fontcolor=blue;');
    WriteLn(f, '');

    emailNormalizado := NormalizarEmail(emailUsuario);
    idx := 0;
    actual := programados.frente;
    
    while actual <> nil do
    begin
      if ContieneDestinatario(String(actual^.destinatario), emailNormalizado) then
      begin
        Inc(idx);
        estado := ObtenerEstadoCorreo(actual^.id);
        if estado = 'L' then 
        begin
          estado := 'LEÍDO';
          colorFondo := '#E6F3FF';
        end
        else
        begin
          estado := 'NO LEÍDO';
          colorFondo := '#FFE6E6';
        end;
        
        WriteLn(f, Format('  correo_%d [label="ID: %d|De: %s|Asunto: %s|Estado: %s", fillcolor="%s"];',
                 [idx, actual^.id, 
                  LimitarTexto(SanearTexto(String(actual^.remitente)), 25),
                  LimitarTexto(SanearTexto(String(actual^.asunto)), 30),
                  estado,
                  colorFondo]));
        
        if idx > 1 then
          WriteLn(f, Format('  correo_%d -> correo_%d [style=dotted];', [idx-1, idx]));
      end;
      actual := actual^.siguiente;
    end;

    if idx = 0 then
      WriteLn(f, '  vacio [label="📭 Sin correos recibidos", fillcolor="#F0F0F0", fontcolor="gray"];');

    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
end;

procedure GenerarReportePapelera(const emailUsuario: String; var papelera: TPila; const rutaDot: String);
var
  f: Text;
  actual: pila2.PCorreo;
  idx: Integer;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph Papelera {');
    WriteLn(f, '  rankdir=TB;');
    WriteLn(f, '  node [shape=box, style=filled, fontname="Arial", fontsize=9, fillcolor="#FFD6D6"];');
    WriteLn(f, '  edge [color=red, style=bold];');
    WriteLn(f, '  label="🗑️ PAPELERA (PILA) - ' + SanearTexto(emailUsuario) + '"; labelloc=t; fontsize=14; fontcolor=red;');
    WriteLn(f, '');

    idx := 0;
    actual := papelera.tope;
    
    while actual <> nil do
    begin
      // Filtrar correos del usuario
      if (actual^.destinatario = emailUsuario) or (actual^.remitente = emailUsuario) then
      begin
        Inc(idx);
        WriteLn(f, Format('  eliminado_%d [label="🗑️ ID: %d\nDe: %s\nPara: %s\nAsunto: %s"];',
                 [idx, actual^.id, 
                  LimitarTexto(SanearTexto(actual^.remitente), 20),
                  LimitarTexto(SanearTexto(actual^.destinatario), 20),
                  LimitarTexto(SanearTexto(actual^.asunto), 25)]));
        
        if idx > 1 then
          WriteLn(f, Format('  eliminado_%d -> eliminado_%d [label="LIFO"];', [idx-1, idx]));
      end;
      actual := actual^.siguiente;
    end;

    if idx = 0 then
      WriteLn(f, '  vacia [label="🗑️ Papelera vacía", fillcolor="#F0F0F0", fontcolor="gray"];');

    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
end;

procedure GenerarReporteProgramados(const emailUsuario: String; var programados: TCola; const rutaDot: String);
var
  f: Text;
  actual: cola2.PCorreo;
  idx: Integer;
  estado: String;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph Programados {');
    WriteLn(f, '  rankdir=LR;');
    WriteLn(f, '  node [shape=ellipse, style=filled, fontname="Arial", fontsize=9, fillcolor="#FFFACD"];');
    WriteLn(f, '  edge [color=orange, style=bold];');
    WriteLn(f, '  label="📅 CORREOS PROGRAMADOS (COLA) - ' + SanearTexto(emailUsuario) + '"; labelloc=t; fontsize=14; fontcolor=orange;');
    WriteLn(f, '');

    idx := 0;
    actual := programados.frente;
    
    while actual <> nil do
    begin
      // Solo correos del usuario
      if actual^.remitente = emailUsuario then
      begin
        estado := ObtenerEstadoCorreo(actual^.id);
        if estado = 'PROGRAMADO' then
        begin
          Inc(idx);
          WriteLn(f, Format('  prog_%d [label="📅 ID: %d\nPara: %s\nAsunto: %s\nEstado: PENDIENTE"];',
                   [idx, actual^.id, 
                    LimitarTexto(SanearTexto(String(actual^.destinatario)), 25),
                    LimitarTexto(SanearTexto(String(actual^.asunto)), 30)]));
          
          if idx > 1 then
            WriteLn(f, Format('  prog_%d -> prog_%d [label="FIFO"];', [idx-1, idx]));
        end;
      end;
      actual := actual^.siguiente;
    end;

    if idx = 0 then
      WriteLn(f, '  vacio [label="📅 Sin correos programados", fillcolor="#F0F0F0", fontcolor="gray"];');

    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
end;

procedure GenerarReporteContactos(const emailUsuario: String; var usuarios: TListaSimple; const rutaDot: String);
var
  f: Text;
  actual: PUsuario;
  idx: Integer;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph Contactos {');
    WriteLn(f, '  rankdir=LR;');
    WriteLn(f, '  node [shape=record, style=filled, fontname="Arial", fontsize=9, fillcolor="#E6FFE6"];');
    WriteLn(f, '  edge [color=green];');
    WriteLn(f, '  label="👥 CONTACTOS (LISTA SIMPLE) - ' + SanearTexto(emailUsuario) + '"; labelloc=t; fontsize=14; fontcolor=green;');
    WriteLn(f, '');

    idx := 0;
    actual := usuarios.cabeza;
    
    while actual <> nil do
    begin
      Inc(idx);
      WriteLn(f, Format('  contacto_%d [label="👤 ID: %d|Nombre: %s|Usuario: %s|Email: %s|Tel: %s"];',
               [idx, actual^.id,
                LimitarTexto(SanearTexto(String(actual^.nombre)), 20),
                LimitarTexto(SanearTexto(String(actual^.usuario)), 15),
                LimitarTexto(SanearTexto(String(actual^.email)), 25),
                LimitarTexto(SanearTexto(String(actual^.telefono)), 15)]));
      
      if idx > 1 then
        WriteLn(f, Format('  contacto_%d -> contacto_%d;', [idx-1, idx]));
        
      actual := actual^.siguiente;
    end;

    if idx = 0 then
      WriteLn(f, '  vacio [label="👥 Sin contactos", fillcolor="#F0F0F0", fontcolor="gray"];');

    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
end;

// ✅ NUEVA: Función para generar reporte de blockchain
procedure GenerarReporteBlockchain(const emailUsuario: String; var blockchainMail: TBlockchain; const rutaDot: String);
var
  f: Text;
  actual: PBloque;
  contador: Integer;
  esDelUsuario: Boolean;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph BlockchainCorreos {');
    WriteLn(f, '  rankdir=LR;');
    WriteLn(f, '  node [shape=record, style=filled, fontname="Arial"];');
    WriteLn(f, '  edge [color="#4F81BD", penwidth=2];');
    WriteLn(f, '  label="⛓️ BLOCKCHAIN DE CORREOS\\nUsuario: ', SanearTexto(emailUsuario), '"; labelloc=t; fontsize=14; fontcolor=blue;');
    WriteLn(f, '');
    
    contador := 0;
    actual := blockchainMail.cabeza;
    
    // Verificar si hay bloques
    if actual = nil then
    begin
      WriteLn(f, '  vacio [label="⛓️ Blockchain vacía\\nNo hay correos registrados", fillcolor="#F0F0F0", fontcolor="gray"];');
    end
    else
    begin
      // Recorrer blockchain del más reciente al más antiguo
      while actual <> nil do
      begin
        Inc(contador);
        
        // Determinar si el bloque es relevante para el usuario
        esDelUsuario := (actual^.data.remitente = emailUsuario) or (actual^.data.destinatario = emailUsuario);
        
        // Colorear según tipo de bloque
        if actual^.index = 0 then
        begin
          // Bloque génesis
          WriteLn(f, Format('  bloque_%d [label="🔗 GÉNESIS\\nIndex: %d\\nTimestamp: %s\\nHash: %s...\\nNonce: %d", fillcolor="#FFD700"];',
                           [actual^.index, actual^.index, actual^.timestamp, 
                            Copy(actual^.hash, 1, 16), actual^.nonce]));
        end
        else if esDelUsuario then
        begin
          // Bloque del usuario (enviado o recibido)
          WriteLn(f, Format('  bloque_%d [label="📧 CORREO DEL USUARIO\\nIndex: %d\\nID Correo: %d\\nDe: %s\\nPara: %s\\nAsunto: %s\\nTimestamp: %s\\nHash: %s...\\nNonce: %d", fillcolor="#FFE6E6"];',
                           [actual^.index, actual^.index, actual^.data.id,
                            Copy(SanearTexto(actual^.data.remitente), 1, 15),
                            Copy(SanearTexto(actual^.data.destinatario), 1, 15),
                            Copy(SanearTexto(actual^.data.asunto), 1, 25),
                            actual^.timestamp,
                            Copy(actual^.hash, 1, 16), actual^.nonce]));
        end
        else
        begin
          // Bloque de otros usuarios
          WriteLn(f, Format('  bloque_%d [label="📦 BLOQUE\\nIndex: %d\\nCorreo ID: %d\\nTimestamp: %s\\nHash: %s...\\nNonce: %d", fillcolor="#E6F3FF"];',
                           [actual^.index, actual^.index, actual^.data.id,
                            actual^.timestamp,
                            Copy(actual^.hash, 1, 16), actual^.nonce]));
        end;
        
        // Conexión al bloque anterior (siguiente en la lista enlazada)
        if actual^.siguiente <> nil then
          WriteLn(f, Format('  bloque_%d -> bloque_%d [label="Previous Hash", fontsize=8];', 
                           [actual^.index, actual^.siguiente^.index]));
        
        actual := actual^.siguiente;
      end;
      
      // Agregar información adicional
      WriteLn(f, '');
      WriteLn(f, '  info [label="ℹ️ INFORMACIÓN BLOCKCHAIN\\nTotal bloques: ', contador, '\\nDificultad: ', blockchainMail.difficulty, '\\nAlgoritmo: Proof of Work\\nInserción: Más reciente al inicio", shape=note, fillcolor="#FFFFCC"];');
    end;
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
  
  WriteLn('⛓️ Reporte blockchain generado: ', rutaDot);
end;

// ✅ AGREGAR procedimiento para reporte de Merkle Tree
procedure GenerarReporteMerklePrivados(const emailUsuario: String; var merklePrivados: TArbolMerkle; const rutaDot: String);
var
  totalCorreosUsuario: Integer;
begin
  totalCorreosUsuario := ContarCorreosPrivadosDelUsuario(merklePrivados, emailUsuario);
  
  WriteLn('🔒 Generando reporte Merkle Tree para usuario: ', emailUsuario);
  WriteLn('📊 Correos privados del usuario: ', totalCorreosUsuario);
  
  // Generar el reporte usando la función del merkle_tree
  GenerarReporteMerkle(merklePrivados, rutaDot);
  
  WriteLn('✅ Reporte Merkle Tree generado: ', rutaDot);
end;

procedure GenerarReportesCompletos(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain; var merklePrivados: TArbolMerkle); // ✅ AGREGAR merklePrivados
var
  rutaDir: String;
  // ✅ EXPANDIR array para incluir merkle tree
  archivos: array[1..8] of String;
  nombres: array[1..8] of String;
  i: Integer;
  pngsGenerados: Integer;
begin
  CrearDirectorioReportes(emailUsuario, rutaDir);
  
  // Definir nombres de archivos (actualizado)
  archivos[1] := rutaDir + '/correos-recibidos.dot';
  archivos[2] := rutaDir + '/papelera.dot';
  archivos[3] := rutaDir + '/programados.dot';
  archivos[4] := rutaDir + '/contactos.dot';
  archivos[5] := rutaDir + '/favoritos.dot';
  archivos[6] := rutaDir + '/borradores.dot';
  archivos[7] := rutaDir + '/blockchain.dot';
  archivos[8] := rutaDir + '/merkle-tree-privados.dot'; // ✅ NUEVO
  
  nombres[1] := 'Correos Recibidos';
  nombres[2] := 'Papelera';
  nombres[3] := 'Correos Programados';
  nombres[4] := 'Contactos';
  nombres[5] := 'Favoritos';
  nombres[6] := 'Borradores';
  nombres[7] := 'Blockchain';
  nombres[8] := 'Correos Privados (Merkle Tree)'; // ✅ NUEVO
  
  WriteLn('📊 Generando reportes completos para: ', emailUsuario);
  WriteLn('📁 Directorio: ', rutaDir);
  
  // Generar todos los reportes DOT (actualizado)
  GenerarReporteCorreosRecibidos(emailUsuario, programados, archivos[1]);
  GenerarReportePapelera(emailUsuario, papelera, archivos[2]);
  GenerarReporteProgramados(emailUsuario, programados, archivos[3]);
  GenerarReporteContactos(emailUsuario, usuarios, archivos[4]);
  GenerarReporteFavoritos(emailUsuario, favoritos, archivos[5]);
  GenerarReporteBorradores(emailUsuario, borradores, archivos[6]);
  GenerarReporteBlockchain(emailUsuario, blockchainMail, archivos[7]);
  GenerarReporteMerklePrivados(emailUsuario, merklePrivados, archivos[8]); // ✅ NUEVO
  
  WriteLn('✅ Todos los archivos DOT generados exitosamente');
  
  // Intentar generar PNGs con Graphviz si está disponible
  pngsGenerados := 0;
  if ExecuteProcess('/bin/sh', ['-c', 'command -v dot >/dev/null 2>&1'], []) = 0 then
  begin
    WriteLn('🖼️ Graphviz detectado, generando imágenes PNG...');
    for i := 1 to 8 do // ✅ ACTUALIZAR a 8
    begin
      if ExecuteProcess('/bin/sh', ['-c', 'dot -Tpng "' + archivos[i] + '" -o "' + ChangeFileExt(archivos[i], '.png') + '"'], []) = 0 then
      begin
        Inc(pngsGenerados);
        WriteLn('✅ PNG generado: ', nombres[i]);
      end
      else
        WriteLn('⚠️ Error generando PNG: ', nombres[i]);
    end;
  end
  else
    WriteLn('ℹ️ Graphviz no está instalado, solo se generaron archivos DOT');
  
  // Mostrar resumen
  WriteLn('');
  WriteLn('📊 RESUMEN DE REPORTES GENERADOS:');
  WriteLn('=================================');
  WriteLn('👤 Usuario: ', emailUsuario);
  WriteLn('📁 Directorio: ', rutaDir);
  WriteLn('📄 Archivos DOT: 8'); // ✅ ACTUALIZAR
  WriteLn('🖼️ Archivos PNG: ', pngsGenerados);
  WriteLn('');
  for i := 1 to 8 do // ✅ ACTUALIZAR a 8
    WriteLn('  ✓ ', nombres[i], ': ', ExtractFileName(archivos[i]));
  
  if pngsGenerados > 0 then
  begin
    WriteLn('');
    WriteLn('🎉 ¡Reportes generados exitosamente!');
    WriteLn('💡 Abre los archivos PNG para visualizar los gráficos.');
    WriteLn('⛓️ El reporte de blockchain muestra la cadena de bloques con correos del usuario resaltados.');
    WriteLn('🔒 El reporte de Merkle Tree muestra la estructura criptográfica de correos privados.');
  end;
end;

// Función auxiliar para generar nodos del árbol B recursivamente
procedure GenerarNodosArbolB(var f: Text; nodo: PNodoB; const emailUsuario: String; var contadorNodos: Integer);
var
  i: Integer;
  colorNodo: String;
  labelNodo: String;
  tieneCorreosUsuario: Boolean;
  nodoID: Integer;
  correosUsuario: String;
  conteoCorreos: Integer;
  contadorAntes: Integer; // Mover la declaración aquí
begin
  if nodo = nil then Exit;
  
  // Verificar si este nodo contiene correos del usuario
  tieneCorreosUsuario := False;
  correosUsuario := '';
  conteoCorreos := 0;
  
  for i := 1 to nodo^.n do
  begin
    if (nodo^.claves[i].destinatario = emailUsuario) or (nodo^.claves[i].remitente = emailUsuario) then
    begin
      tieneCorreosUsuario := True;
      Inc(conteoCorreos);
      if correosUsuario <> '' then
        correosUsuario := correosUsuario + '\\n';
      correosUsuario := correosUsuario + IntToStr(nodo^.claves[i].id);
    end;
  end;
  
  // Si no tiene correos del usuario, seguir buscando en hijos
  if not tieneCorreosUsuario then
  begin
    if not nodo^.hoja then
    begin
      for i := 0 to nodo^.n do
        GenerarNodosArbolB(f, nodo^.hijos[i], emailUsuario, contadorNodos);
    end;
    Exit;
  end;
  
  Inc(contadorNodos);
  nodoID := contadorNodos;
  
  // Determinar color según si es hoja o nodo interno
  if nodo^.hoja then
    colorNodo := '#FFE4B5'  // Naranja claro para hojas
  else
    colorNodo := '#E6F3FF'; // Azul claro para nodos internos
  
  // Construir label del nodo mostrando solo IDs de correos del usuario
  if nodo^.hoja then
    labelNodo := 'HOJA ' + IntToStr(nodoID)
  else
    labelNodo := 'NODO ' + IntToStr(nodoID);
    
  labelNodo := labelNodo + '\\nClaves: ' + IntToStr(conteoCorreos) + '\\n';
  labelNodo := labelNodo + correosUsuario;
  
  // Crear nodo en el gráfico
  WriteLn(f, Format('  nodoB_%d [label="%s", fillcolor="%s", shape="record"];',
                   [nodoID, labelNodo, colorNodo]));
  
  // Si no es hoja, generar conexiones a hijos que contengan correos del usuario
  if not nodo^.hoja then
  begin
    for i := 0 to nodo^.n do
    begin
      if nodo^.hijos[i] <> nil then
      begin
        // Guardar el contador actual antes de procesar el hijo
        contadorAntes := contadorNodos;
        
        // Procesar hijo recursivamente
        GenerarNodosArbolB(f, nodo^.hijos[i], emailUsuario, contadorNodos);
        
        // Si se generó algún nodo hijo (contador aumentó), crear conexión
        if contadorNodos > contadorAntes then
        begin
          WriteLn(f, Format('  nodoB_%d -> nodoB_%d [label="H%d", color="purple", fontcolor="purple"];', 
                           [nodoID, contadorAntes + 1, i]));
        end;
      end;
    end;
  end;
end;

procedure GenerarReporteFavoritos(const emailUsuario: String; var favoritos: PNodoB; const rutaDot: String);
var
  f: Text;
  contadorNodos: Integer;
  tieneCorreos: Boolean;
  i: Integer;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph FavoritosArbolB {');
    WriteLn(f, '  rankdir=TB;');
    WriteLn(f, '  node [style=filled, fontname="Arial", fontsize=10];');
    WriteLn(f, '  edge [fontname="Arial", fontsize=8];');
    WriteLn(f, '  label="⭐ FAVORITOS (ÁRBOL B) - ' + SanearTexto(emailUsuario) + '\\nEstructura Real del Árbol B con Nodos y Conexiones"; labelloc=t; fontsize=14; fontcolor=orange;');
    WriteLn(f, '');
    
    // Agregar leyenda
    WriteLn(f, '  subgraph cluster_leyenda {');
    WriteLn(f, '    label="Leyenda del Árbol B";');
    WriteLn(f, '    style=filled;');
    WriteLn(f, '    fillcolor=lightgray;');
    WriteLn(f, '    leyenda_hoja [label="Nodos Hoja\\n(Datos finales)", fillcolor="#FFE4B5", shape="record"];');
    WriteLn(f, '    leyenda_interno [label="Nodos Internos\\n(Navegación)", fillcolor="#E6F3FF", shape="record"];');
    WriteLn(f, '    leyenda_conexion [label="Conexión Padre-Hijo", color="purple"];');
    WriteLn(f, '    leyenda_estructura [label="Estructura: Raíz → Nodos → Hojas", shape="plaintext"];');
    WriteLn(f, '  }');
    WriteLn(f, '');
    
    // Verificar si hay favoritos del usuario - verificación simple
    contadorNodos := 0;
    tieneCorreos := False;
    
    if favoritos <> nil then
    begin
      // Verificación simple en la raíz
      for i := 1 to favoritos^.n do
      begin
        if (favoritos^.claves[i].destinatario = emailUsuario) or (favoritos^.claves[i].remitente = emailUsuario) then
        begin
          tieneCorreos := True;
          Break;
        end;
      end;
      
      // Si no hay en la raíz, verificar recursivamente si existe alguno
      if not tieneCorreos and not favoritos^.hoja then
      begin
        // Aquí podríamos hacer una búsqueda más profunda si es necesario
        tieneCorreos := True; // Asumimos que puede haber datos más profundo
      end;
    end;
    
    if (favoritos = nil) or not tieneCorreos then
    begin
      WriteLn(f, '  vacio [label="⭐ Árbol B vacío\\nNo hay favoritos del usuario\\n\\nPara agregar favoritos:\\n1. Ve a tu bandeja\\n2. Selecciona un correo\\n3. Clic en ⭐ A Favoritos", fillcolor="#F0F0F0", fontcolor="gray", shape="box"];');
    end
    else
    begin
      // Generar estructura real del árbol B
      GenerarNodosArbolB(f, favoritos, emailUsuario, contadorNodos);
      
      // Agregar información del árbol si se generaron nodos
      if contadorNodos > 0 then
      begin
        WriteLn(f, '');
        WriteLn(f, '  info [label="Propiedades del Árbol B:\\n• Cada nodo puede tener múltiples claves\\n• Hojas en el mismo nivel\\n• Autobalanceado\\n• Búsqueda eficiente O(log n)\\n• Nodos mostrados: ' + IntToStr(contadorNodos) + '", shape="note", fillcolor="#FFFFCC"];');
        
        // Conectar info con la estructura
        WriteLn(f, '  nodoB_1 -> info [style="dotted", color="gray"];');
      end
      else
      begin
        WriteLn(f, '  vacio2 [label="⭐ Sin favoritos del usuario\\nen la estructura actual del árbol", fillcolor="#F0F0F0", fontcolor="gray", shape="box"];');
      end;
    end;
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
  
  WriteLn('⭐ Reporte Árbol B de favoritos generado: ', rutaDot);
end;

procedure GenerarReporteBorradores(const emailUsuario: String; var borradores: PCorreoAVL; const rutaDot: String);
var
  f: Text;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph BorradoresAVL {');
    WriteLn(f, '  rankdir=TB;');
    WriteLn(f, '  node [style=filled, fontname="Arial", fontsize=10];');
    WriteLn(f, '  edge [fontname="Arial", fontsize=8];');
    WriteLn(f, '  label="📝 BORRADORES (ÁRBOL AVL) - ' + SanearTexto(emailUsuario) + '\\nEstructura: Rojo=Izquierdo, Azul=Derecho"; labelloc=t; fontsize=14; fontcolor=purple;');
    WriteLn(f, '');
    
    // Agregar leyenda
    WriteLn(f, '  subgraph cluster_leyenda {');
    WriteLn(f, '    label="Leyenda";');
    WriteLn(f, '    style=filled;');
    WriteLn(f, '    fillcolor=lightgray;');
    WriteLn(f, '    leyenda_raiz [label="Nodos Cercanos\\na la Raíz", fillcolor="#E6F3FF", shape="diamond"];');
    WriteLn(f, '    leyenda_inter [label="Nodos\\nIntermedios", fillcolor="#FFF2E6", shape="diamond"];');
    WriteLn(f, '    leyenda_hoja [label="Nodos\\nProfundos", fillcolor="#FFE6E6", shape="diamond"];');
    WriteLn(f, '    leyenda_izq [label="Hijo Izquierdo", color="red"];');
    WriteLn(f, '    leyenda_der [label="Hijo Derecho", color="blue"];');
    WriteLn(f, '  }');
    WriteLn(f, '');
    
    // Verificar si hay borradores
    if borradores = nil then
    begin
      WriteLn(f, '  vacio [label="📝 Árbol AVL vacío\\nNo hay borradores del usuario", fillcolor="#F0F0F0", fontcolor="gray", shape="box"];');
    end
    else
    begin
      // Generar estructura del árbol AVL
      GenerarNodosAVL(f, borradores, emailUsuario);
      
      // Agregar información del árbol
      WriteLn(f, '');
      WriteLn(f, '  info [label="Propiedades del Árbol AVL:\\n• Factor de balance: [-1, 0, 1]\\n• Altura balanceada automáticamente\\n• Búsqueda O(log n)", shape="note", fillcolor="#FFFFCC"];');
    end;
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
  
  WriteLn('📝 Reporte AVL de borradores generado: ', rutaDot);
end;

procedure GenerarReporteBSTComunidades(const rutaDot: String);
var
  f: Text;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph BSTComunidades {');
    WriteLn(f, '  rankdir=TB;');
    WriteLn(f, '  node [shape=record, style=filled, fontname="Arial", fontsize=10];');
    WriteLn(f, '  edge [fontname="Arial", fontsize=8];');
    WriteLn(f, '  label="🌳 ÁRBOL BST DE COMUNIDADES\\nEstructura: Rojo=BST, Azul=Jerarquía"; labelloc=t; fontsize=16; fontcolor=green;');
    WriteLn(f, '');
    WriteLn(f, '  // Leyenda');
    WriteLn(f, '  subgraph cluster_leyenda {');
    WriteLn(f, '    label="Leyenda";');
    WriteLn(f, '    style=filled;');
    WriteLn(f, '    fillcolor=lightgray;');
    WriteLn(f, '    leyenda_principal [label="Comunidad\\nPrincipal", fillcolor="#E6F7FF", shape="box"];');
    WriteLn(f, '    leyenda_sub [label="Subcomunidad", fillcolor="#FFE4B5", shape="ellipse"];');
    WriteLn(f, '    leyenda_bst [label="Conexión BST", color="red"];');
    WriteLn(f, '    leyenda_jerarquia [label="Relación Padre-Hijo", color="blue", style="dashed"];');
    WriteLn(f, '    leyenda_principal -> leyenda_sub [color="red", label="BST"];');
    WriteLn(f, '    leyenda_principal -> leyenda_sub [color="blue", style="dashed", label="Jerarquía"];');
    WriteLn(f, '  }');
    WriteLn(f, '');
    
    // Verificar si hay comunidades
    if ContarComunidades(ArbolComunidades) = 0 then
    begin
      WriteLn(f, '  vacio [label="🌳 Árbol BST vacío\\nNo hay comunidades creadas", fillcolor="#F0F0F0", fontcolor="gray"];');
    end
    else
    begin
      // Generar estructura del árbol BST
      GenerarNodosBST(f, ArbolComunidades);
    end;
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
  
  WriteLn('🌳 Reporte BST generado: ', rutaDot);
end;

procedure GenerarNodosBST(var f: Text; nodo: PNodoComunidadBST);
var
  colorNodo, formaEtiqueta: String;
begin
  if nodo = nil then Exit;
  
  // Determinar color y forma según el tipo de comunidad
  if nodo^.esSubcomunidad then
  begin
    colorNodo := '#FFE4B5'; // Color naranja claro para subcomunidades
    formaEtiqueta := 'Subcomunidad';
  end
  else
  begin
    colorNodo := '#E6F7FF'; // Color azul claro para comunidades principales
    formaEtiqueta := 'Comunidad Principal';
  end;
  
  // Crear nodo actual con información de jerarquía
  if nodo^.esSubcomunidad then
  begin
    WriteLn(f, Format('  nodo_%d [label="%s\\nID: %d\\n%s\\nCreador: %s\\nMensajes: %d", fillcolor="%s", shape="ellipse"];',
                     [nodo^.id, formaEtiqueta, nodo^.id, SanearTexto(nodo^.nombre), 
                      SanearTexto(nodo^.creador), nodo^.totalMensajes, colorNodo]));
    
    // Si es subcomunidad, conectar con el padre
    if nodo^.comunidadPadre <> nil then
      WriteLn(f, Format('  nodo_%d -> nodo_%d [label="subcomunidad de", color="blue", style="dashed"];', 
                       [nodo^.comunidadPadre^.id, nodo^.id]));
  end
  else
  begin
    WriteLn(f, Format('  nodo_%d [label="%s\\nID: %d\\n%s\\nMensajes: %d", fillcolor="%s", shape="box"];',
                     [nodo^.id, formaEtiqueta, nodo^.id, SanearTexto(nodo^.nombre), nodo^.totalMensajes, colorNodo]));
  end;
  
  // Generar conexiones BST normales (estructura del árbol)
  if nodo^.izquierdo <> nil then
  begin
    WriteLn(f, Format('  nodo_%d -> nodo_%d [label="L", color="red"];', [nodo^.id, nodo^.izquierdo^.id]));
    GenerarNodosBST(f, nodo^.izquierdo);
  end;
  
  if nodo^.derecho <> nil then
  begin
    WriteLn(f, Format('  nodo_%d -> nodo_%d [label="R", color="red"];', [nodo^.id, nodo^.derecho^.id]));
    GenerarNodosBST(f, nodo^.derecho);
  end;
end;

procedure GenerarNodosAVL(var f: Text; nodo: PCorreoAVL; const emailUsuario: String);
var
  colorNodo: String;
  factorBalance: Integer;
begin
  if nodo = nil then Exit;
  
  // Solo procesar nodos del usuario actual
  if nodo^.remitente <> emailUsuario then
  begin
    // Continuar recorrido para encontrar nodos del usuario
    GenerarNodosAVL(f, nodo^.izquierdo, emailUsuario);
    GenerarNodosAVL(f, nodo^.derecho, emailUsuario);
    Exit;
  end;
  
  // Determinar color según la altura del nodo
  if nodo^.altura <= 2 then
    colorNodo := '#E6F3FF'  // Azul claro para nodos cerca de la raíz
  else if nodo^.altura <= 4 then
    colorNodo := '#FFF2E6'  // Naranja claro para nodos intermedios
  else
    colorNodo := '#FFE6E6'; // Rosa claro para nodos más profundos
  
  // CALIFICACION DE EDD FASE 2
  // MODIFICACION: Quitar el remitente de el reporte del arbol avl, solo mostrar id, asunto y altura
  WriteLn(f, Format('  nodo_%d [label="ID: %d\\nAsunto: %s\\nAltura: %d", fillcolor="%s", shape="oval"];',
                   [nodo^.id, nodo^.id, 
                    LimitarTexto(SanearTexto(nodo^.asunto), 20),
                    nodo^.altura, colorNodo]));
  
  // Generar conexiones a hijos si existen
  if nodo^.izquierdo <> nil then
  begin
    // Verificar si el hijo izquierdo es del usuario actual
    if nodo^.izquierdo^.remitente = emailUsuario then
      WriteLn(f, Format('  nodo_%d -> nodo_%d [label="L", color="red", fontcolor="red"];', 
                       [nodo^.id, nodo^.izquierdo^.id]));
    
    GenerarNodosAVL(f, nodo^.izquierdo, emailUsuario);
  end;
  
  if nodo^.derecho <> nil then
  begin
    // Verificar si el hijo derecho es del usuario actual
    if nodo^.derecho^.remitente = emailUsuario then
      WriteLn(f, Format('  nodo_%d -> nodo_%d [label="R", color="blue", fontcolor="blue"];', 
                       [nodo^.id, nodo^.derecho^.id]));
    
    GenerarNodosAVL(f, nodo^.derecho, emailUsuario);
  end;
  
  // Mostrar factor de balance si es diferente de 0
  factorBalance := 0;
  if nodo^.izquierdo <> nil then
    Inc(factorBalance, nodo^.izquierdo^.altura);
  if nodo^.derecho <> nil then
    Dec(factorBalance, nodo^.derecho^.altura);
  
  if factorBalance <> 0 then
    WriteLn(f, Format('  balance_%d [label="FB: %d", shape="plaintext", fontsize=10];', 
                     [nodo^.id, factorBalance]));
end;

end.
