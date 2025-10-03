unit reports;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, cola2, listasimple2, arbol_avl, arbol_b, pila2, arbolbst;

// Función original
procedure GenerarGraficoBandeja(const emailDestino: String; var programados: TCola; const rutaDot: String);

// Nuevas funciones para reportes completos
procedure GenerarReportesCompletos(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila);
procedure GenerarReporteCorreosRecibidos(const emailUsuario: String; var programados: TCola; const rutaDot: String);
procedure GenerarReportePapelera(const emailUsuario: String; var papelera: TPila; const rutaDot: String);
procedure GenerarReporteProgramados(const emailUsuario: String; var programados: TCola; const rutaDot: String);
procedure GenerarReporteContactos(const emailUsuario: String; var usuarios: TListaSimple; const rutaDot: String);
procedure GenerarReporteFavoritos(const emailUsuario: String; var favoritos: PNodoB; const rutaDot: String);
procedure GenerarReporteBorradores(const emailUsuario: String; var borradores: PCorreoAVL; const rutaDot: String);
procedure GenerarReporteBSTComunidades(const rutaDot: String);

// Función auxiliar para generar nodos BST recursivamente
procedure GenerarNodosBST(var f: Text; nodo: PNodoComunidadBST);

implementation

uses
  json_loader, comunidad; // Agregar comunidad para acceder a ArbolComunidades

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

// Callback para recolectar favoritos
var
  FavoritosFile: Text;
  FavoritosIdx: Integer;
  FavoritosUsuario: String;

procedure CallbackFavoritos(correo: TCorreoB; data: Pointer);
begin
  if (correo.destinatario = FavoritosUsuario) or (correo.remitente = FavoritosUsuario) then
  begin
    Inc(FavoritosIdx);
    WriteLn(FavoritosFile, Format('  fav_%d [label="⭐ ID: %d\nDe: %s\nPara: %s\nAsunto: %s"];',
             [FavoritosIdx, correo.id,
              LimitarTexto(SanearTexto(correo.remitente), 20),
              LimitarTexto(SanearTexto(correo.destinatario), 20),
              LimitarTexto(SanearTexto(correo.asunto), 25)]));
  end;
end;

procedure GenerarReporteFavoritos(const emailUsuario: String; var favoritos: PNodoB; const rutaDot: String);
begin
  AssignFile(FavoritosFile, rutaDot);
  Rewrite(FavoritosFile);
  try
    WriteLn(FavoritosFile, 'digraph Favoritos {');
    WriteLn(FavoritosFile, '  rankdir=TB;');
    WriteLn(FavoritosFile, '  node [shape=star, style=filled, fontname="Arial", fontsize=9, fillcolor="#FFE4B5"];');
    WriteLn(FavoritosFile, '  edge [color=gold, style=bold];');
    WriteLn(FavoritosFile, '  label="⭐ FAVORITOS (ÁRBOL B) - ' + SanearTexto(emailUsuario) + '"; labelloc=t; fontsize=14; fontcolor=orange;');
    WriteLn(FavoritosFile, '');

    FavoritosIdx := 0;
    FavoritosUsuario := emailUsuario;
    
    if favoritos <> nil then
      RecorridoInOrden(favoritos, @CallbackFavoritos, nil);

    if FavoritosIdx = 0 then
      WriteLn(FavoritosFile, '  vacio [label="⭐ Sin favoritos", fillcolor="#F0F0F0", fontcolor="gray"];');

    WriteLn(FavoritosFile, '}');
  finally
    CloseFile(FavoritosFile);
  end;
end;

// Callback para recolectar borradores
var
  BorradoresFile: Text;
  BorradoresIdx: Integer;
  BorradoresUsuario: String;

procedure CallbackBorradores(correo: PCorreoAVL; data: Pointer);
begin
  if correo^.remitente = BorradoresUsuario then
  begin
    Inc(BorradoresIdx);
    WriteLn(BorradoresFile, Format('  borr_%d [label="📝 ID: %d\nPara: %s\nAsunto: %s\nAltura: %d"];',
             [BorradoresIdx, correo^.id,
              LimitarTexto(SanearTexto(correo^.destinatario), 25),
              LimitarTexto(SanearTexto(correo^.asunto), 30),
              correo^.altura]));
  end;
end;

procedure GenerarReporteBorradores(const emailUsuario: String; var borradores: PCorreoAVL; const rutaDot: String);
begin
  AssignFile(BorradoresFile, rutaDot);
  Rewrite(BorradoresFile);
  try
    WriteLn(BorradoresFile, 'digraph Borradores {');
    WriteLn(BorradoresFile, '  rankdir=TB;');
    WriteLn(BorradoresFile, '  node [shape=diamond, style=filled, fontname="Arial", fontsize=9, fillcolor="#E6E6FA"];');
    WriteLn(BorradoresFile, '  edge [color=purple];');
    WriteLn(BorradoresFile, '  label="📝 BORRADORES (ÁRBOL AVL) - ' + SanearTexto(emailUsuario) + '"; labelloc=t; fontsize=14; fontcolor=purple;');
    WriteLn(BorradoresFile, '');

    BorradoresIdx := 0;
    BorradoresUsuario := emailUsuario;
    
    if borradores <> nil then
      RecorridoPersonalizado(borradores, @CallbackBorradores, nil);

    if BorradoresIdx = 0 then
      WriteLn(BorradoresFile, '  vacio [label="📝 Sin borradores", fillcolor="#F0F0F0", fontcolor="gray"];');

    WriteLn(BorradoresFile, '}');
  finally
    CloseFile(BorradoresFile);
  end;
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

procedure GenerarReportesCompletos(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila);
var
  rutaDir: String;
  archivos: array[1..6] of String;
  nombres: array[1..6] of String;
  i: Integer;
  pngsGenerados: Integer;
begin
  CrearDirectorioReportes(emailUsuario, rutaDir);
  
  // Definir nombres de archivos
  archivos[1] := rutaDir + '/correos-recibidos.dot';
  archivos[2] := rutaDir + '/papelera.dot';
  archivos[3] := rutaDir + '/programados.dot';
  archivos[4] := rutaDir + '/contactos.dot';
  archivos[5] := rutaDir + '/favoritos.dot';
  archivos[6] := rutaDir + '/borradores.dot';
  
  nombres[1] := 'Correos Recibidos';
  nombres[2] := 'Papelera';
  nombres[3] := 'Correos Programados';
  nombres[4] := 'Contactos';
  nombres[5] := 'Favoritos';
  nombres[6] := 'Borradores';
  
  WriteLn('📊 Generando reportes completos para: ', emailUsuario);
  WriteLn('📁 Directorio: ', rutaDir);
  
  // Generar todos los reportes DOT
  GenerarReporteCorreosRecibidos(emailUsuario, programados, archivos[1]);
  GenerarReportePapelera(emailUsuario, papelera, archivos[2]);
  GenerarReporteProgramados(emailUsuario, programados, archivos[3]);
  GenerarReporteContactos(emailUsuario, usuarios, archivos[4]);
  GenerarReporteFavoritos(emailUsuario, favoritos, archivos[5]);
  GenerarReporteBorradores(emailUsuario, borradores, archivos[6]);
  
  WriteLn('✅ Todos los archivos DOT generados exitosamente');
  
  // Intentar generar PNGs con Graphviz si está disponible
  pngsGenerados := 0;
  if ExecuteProcess('/bin/sh', ['-c', 'command -v dot >/dev/null 2>&1'], []) = 0 then
  begin
    WriteLn('🖼️ Graphviz detectado, generando imágenes PNG...');
    for i := 1 to 6 do
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
  WriteLn('📄 Archivos DOT: 6');
  WriteLn('🖼️ Archivos PNG: ', pngsGenerados);
  WriteLn('');
  for i := 1 to 6 do
    WriteLn('  ✓ ', nombres[i], ': ', ExtractFileName(archivos[i]));
  
  if pngsGenerados > 0 then
  begin
    WriteLn('');
    WriteLn('🎉 ¡Reportes generados exitosamente!');
    WriteLn('💡 Abre los archivos PNG para visualizar los gráficos.');
  end;
end;

end.
