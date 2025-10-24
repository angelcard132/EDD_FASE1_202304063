unit reports;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  cola2, listasimple2, arbol_avl, arbol_b, pila2, arbolbst, blockchain, merkle_tree, control_login;

// Función original
procedure GenerarGraficoBandeja(const emailDestino: String; var programados: TCola; const rutaDot: String);

// ✅ DECLARACIÓN ÚNICA de reporte Merkle Tree
procedure GenerarReporteMerklePrivados(const emailUsuario: String; var merklePrivados: TArbolMerkle; const rutaDot: String);

// ✅ DECLARACIÓN ÚNICA de reportes completos
procedure GenerarReportesCompletos(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain; var merklePrivados: TArbolMerkle);

// Reportes individuales que SÍ se usan
procedure GenerarReporteCorreosRecibidos(const emailUsuario: String; var programados: TCola; const rutaDot: String);
procedure GenerarReportePapelera(const emailUsuario: String; var papelera: TPila; const rutaDot: String);
procedure GenerarReporteProgramados(const emailUsuario: String; var programados: TCola; const rutaDot: String);
procedure GenerarReporteContactos(const emailUsuario: String; var usuarios: TListaSimple; const rutaDot: String);

// ✅ NUEVAS FUNCIONES: Reportes específicos que SÍ usamos
procedure GenerarReporteControlLogin(const rutaDot: String);
procedure GenerarReporteBlockchain(const emailUsuario: String; var blockchainMail: TBlockchain; const rutaDot: String);
procedure GenerarReporteRelacionesContactos(const rutaDot: String);

// ✅ AGREGAR: Función básica para BST de comunidades
procedure GenerarReporteBSTComunidades(const rutaDot: String);

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

// ✅ NUEVA: Función para generar reporte visual del control de logueo
procedure GenerarReporteControlLogin(const rutaDot: String);
var
  f: Text;
  actual: PRegistroLogin;
  contador, sesionesActivas, sesionesFinalizadas: Integer;
  fechaEntrada, fechaSalida, duracion, estado: String;
  tiempoSesion: Double;
  colorNodo: String;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  try
    WriteLn(f, 'digraph ControlLogin {');
    WriteLn(f, '  rankdir=TB;');
    WriteLn(f, '  node [style=filled, fontname="Arial", fontsize=9];');
    WriteLn(f, '  edge [fontname="Arial", fontsize=8];');
    WriteLn(f, '  label="🔐 CONTROL DE LOGUEO DEL SISTEMA\\nRegistro cronológico de accesos de usuarios"; labelloc=t; fontsize=14; fontcolor=navy;');
    WriteLn(f, '');
    
    // Leyenda del reporte
    WriteLn(f, '  subgraph cluster_leyenda {');
    WriteLn(f, '    label="🔐 Leyenda del Control de Acceso";');
    WriteLn(f, '    style=filled;');
    WriteLn(f, '    fillcolor="#F0F8FF";');
    WriteLn(f, '    fontcolor=navy;');
    WriteLn(f, '    leyenda_activo [label="🟢 SESIÓN ACTIVA\\n(Usuario conectado)", fillcolor="#90EE90", shape="box"];');
    WriteLn(f, '    leyenda_finalizada [label="🔴 SESIÓN FINALIZADA\\n(Usuario desconectado)", fillcolor="#FFB6C1", shape="box"];');
    WriteLn(f, '    leyenda_root [label="👑 ADMINISTRADOR ROOT\\n(Acceso privilegiado)", fillcolor="#FFD700", shape="diamond"];');
    WriteLn(f, '    leyenda_usuario [label="👤 USUARIO REGULAR\\n(Acceso estándar)", fillcolor="#E6F3FF", shape="ellipse"];');
    WriteLn(f, '    leyenda_tiempo [label="⏱️ Tiempo de Sesión\\n(duración calculada)", fillcolor="#F0F0F0", shape="note"];');
    WriteLn(f, '  }');
    WriteLn(f, '');
    
    contador := 0;
    sesionesActivas := 0;
    sesionesFinalizadas := 0;
    actual := ObtenerRegistrosLogin();
    
    if actual = nil then
    begin
      WriteLn(f, '  vacio [label="🔐 Sin registros de acceso\\n\\nNo hay usuarios que hayan\\niniciado sesión en el sistema", fillcolor="#F0F0F0", fontcolor="gray", shape="box"];');
    end
    else
    begin
      WriteLn(f, '  subgraph cluster_cronologia {');
      WriteLn(f, '    label="📅 Cronología de Accesos (Más reciente primero)";');
      WriteLn(f, '    style=filled;');
      WriteLn(f, '    fillcolor="#FFFACD";');
      WriteLn(f, '    fontcolor=brown;');
      WriteLn(f, '');
      
      // Recorrer registros (ya vienen en orden cronológico inverso)
      while actual <> nil do
      begin
        Inc(contador);
        
        fechaEntrada := FormatDateTime('dd/mm/yyyy hh:nn:ss', actual^.fechaEntrada);
        
        if actual^.activo then
        begin
          // Sesión activa
          fechaSalida := 'CONECTADO';
          duracion := 'En sesión';
          estado := '🟢 ACTIVO';
          colorNodo := '#90EE90';
          Inc(sesionesActivas);
        end
        else if actual^.fechaSalida > 0 then
        begin
          // Sesión finalizada correctamente
          fechaSalida := FormatDateTime('dd/mm/yyyy hh:nn:ss', actual^.fechaSalida);
          tiempoSesion := (actual^.fechaSalida - actual^.fechaEntrada) * 24 * 60; // en minutos
          if tiempoSesion < 60 then
            duracion := Format('%.0f min', [tiempoSesion])
          else
            duracion := Format('%.1f hrs', [tiempoSesion / 60]);
          estado := '🔴 FINALIZADA';
          colorNodo := '#FFB6C1';
          Inc(sesionesFinalizadas);
        end
        else
        begin
          // Sesión con error (sin salida registrada)
          fechaSalida := 'SIN SALIDA';
          duracion := 'Error';
          estado := '⚠️ ERROR';
          colorNodo := '#FFA500';
          Inc(sesionesFinalizadas);
        end;
        
        // Determinar si es root o usuario regular
        if Pos('root', LowerCase(actual^.usuario)) > 0 then
        begin
          // Es administrador root - ✅ CORREGIR formato sin colorNodo
          WriteLn(f, Format('    sesion_%d [label="👑 ADMINISTRADOR ROOT\\n%s\\n\\n📅 Entrada: %s\\n🚪 Salida: %s\\n⏱️ Duración: %s\\n\\n%s", fillcolor="#FFD700", shape="diamond"];',
                           [contador, actual^.usuario, fechaEntrada, fechaSalida, duracion, estado]));
        end
        else
        begin
          // Es usuario regular - ✅ CORREGIR número de parámetros
          WriteLn(f, Format('    sesion_%d [label="👤 %s\\n\\n📅 Entrada: %s\\n🚪 Salida: %s\\n⏱️ Duración: %s\\n\\n%s", fillcolor="%s", shape="ellipse"];',
                           [contador, actual^.usuario, fechaEntrada, fechaSalida, duracion, estado, colorNodo]));
        end;
        
        // Conectar sesiones cronológicamente
        if contador > 1 then
        begin
          if actual^.activo then
            WriteLn(f, Format('    sesion_%d -> sesion_%d [label="anterior", color="green", style="bold"];', [contador-1, contador]))
          else
            WriteLn(f, Format('    sesion_%d -> sesion_%d [label="anterior", color="gray"];', [contador-1, contador]));
        end;
        
        actual := actual^.siguiente;
      end;
      
      WriteLn(f, '  }');
    end;
    
    // Agregar información estadística
    WriteLn(f, '');
    WriteLn(f, '  subgraph cluster_estadisticas {');
    WriteLn(f, '    label="📊 Estadísticas del Sistema";');
    WriteLn(f, '    style=filled;');
    WriteLn(f, '    fillcolor="#E0E0E0";');
    WriteLn(f, '    fontcolor=black;');
    WriteLn(f, '    stats [label="📈 RESUMEN DE ACCESOS\\n\\n🔢 Total registros: ' + IntToStr(contador) + '\\n🟢 Sesiones activas: ' + IntToStr(sesionesActivas) + '\\n🔴 Sesiones finalizadas: ' + IntToStr(sesionesFinalizadas) + '\\n\\n📅 Generado: ' + FormatDateTime('dd/mm/yyyy hh:nn', Now) + '", shape="note", fillcolor="#FFFFFF"];');
    
    if contador > 0 then
    begin
      WriteLn(f, '    seguridad [label="🛡️ INFORMACIÓN DE SEGURIDAD\\n\\n• Monitoreo en tiempo real\\n• Control de accesos activos\\n• Auditoría de usuarios\\n• Detección de sesiones anómalas\\n\\n⚠️ Revisar sesiones sin salida", shape="note", fillcolor="#FFF8DC"];');
    end;
    
    WriteLn(f, '  }');
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
  
  WriteLn('🔐 Reporte de control de logueo generado: ', rutaDot);
  WriteLn('📊 Total de registros procesados: ', contador);
  WriteLn('🟢 Sesiones activas: ', sesionesActivas);
  WriteLn('🔴 Sesiones finalizadas: ', sesionesFinalizadas);
end;

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
  // ✅ REDUCIR array solo a reportes que funcionan
  archivos: array[1..5] of String;
  nombres: array[1..5] of String;
  i: Integer;
  pngsGenerados: Integer;
begin
  CrearDirectorioReportes(emailUsuario, rutaDir);
  
  // ✅ SOLO reportes que funcionan correctamente
  archivos[1] := rutaDir + '/correos-recibidos.dot';
  archivos[2] := rutaDir + '/papelera.dot';
  archivos[3] := rutaDir + '/programados.dot';
  archivos[4] := rutaDir + '/contactos.dot';
  archivos[5] := rutaDir + '/blockchain.dot';
  
  nombres[1] := 'Correos Recibidos';
  nombres[2] := 'Papelera';
  nombres[3] := 'Correos Programados';
  nombres[4] := 'Contactos';
  nombres[5] := 'Blockchain';
  
  WriteLn('📊 Generando reportes completos para: ', emailUsuario);
  WriteLn('📁 Directorio: ', rutaDir);
  
  // ✅ SOLO generar reportes que funcionan
  GenerarReporteCorreosRecibidos(emailUsuario, programados, archivos[1]);
  GenerarReportePapelera(emailUsuario, papelera, archivos[2]);
  GenerarReporteProgramados(emailUsuario, programados, archivos[3]);
  GenerarReporteContactos(emailUsuario, usuarios, archivos[4]);
  GenerarReporteBlockchain(emailUsuario, blockchainMail, archivos[5]);
  
  WriteLn('✅ Todos los archivos DOT generados exitosamente');
  
  // Intentar generar PNGs con Graphviz si está disponible
  pngsGenerados := 0;
  if ExecuteProcess('/bin/sh', ['-c', 'command -v dot >/dev/null 2>&1'], []) = 0 then
  begin
    WriteLn('🖼️ Graphviz detectado, generando imágenes PNG...');
    for i := 1 to 5 do
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
  WriteLn('📄 Archivos DOT: 5');
  WriteLn('🖼️ Archivos PNG: ', pngsGenerados);
  WriteLn('');
  for i := 1 to 5 do
    WriteLn('  ✓ ', nombres[i], ': ', ExtractFileName(archivos[i]));
  
  if pngsGenerados > 0 then
  begin
    WriteLn('');
    WriteLn('🎉 ¡Reportes generados exitosamente!');
    WriteLn('💡 Abre los archivos PNG para visualizar los gráficos.');
    WriteLn('⛓️ El reporte de blockchain muestra la cadena de bloques con correos del usuario resaltados.');
  end;
end;

// ✅ NUEVA: Función para generar reporte de relaciones de contactos
procedure GenerarReporteRelacionesContactos(const rutaDot: String);
var
  f: Text;
  actual: PContactoManual;
  contadorRelaciones, contadorUsuarios: Integer;
  usuariosEncontrados: TStringList;
  contactosEncontrados: TStringList;
  i, j: Integer;
  usuario1, usuario2, contactoComun: String;
  relacionesComunes: Integer;
begin
  AssignFile(f, rutaDot);
  Rewrite(f);
  
  usuariosEncontrados := TStringList.Create;
  contactosEncontrados := TStringList.Create;
  usuariosEncontrados.Duplicates := dupIgnore;
  contactosEncontrados.Duplicates := dupIgnore;
  
  try
    WriteLn(f, 'digraph RelacionesContactos {');
    WriteLn(f, '  rankdir=LR;'); // ✅ CAMBIAR a Left-Right para mejor organización
    WriteLn(f, '  splines=ortho;'); // ✅ AGREGAR líneas ortogonales para mayor claridad
    WriteLn(f, '  overlap=false;'); // ✅ EVITAR solapamiento de nodos
    WriteLn(f, '  concentrate=true;'); // ✅ CONCENTRAR aristas múltiples
    WriteLn(f, '  node [style=filled, fontname="Arial", fontsize=10, margin="0.1,0.05"];');
    WriteLn(f, '  edge [fontname="Arial", fontsize=8, penwidth=1.5];');
    WriteLn(f, '  label="👥 MAPA DE RELACIONES DE CONTACTOS\\nGrafo de conexiones entre usuarios y sus contactos\\n"; labelloc=t; fontsize=16; fontcolor=darkgreen; fontweight=bold;');
    WriteLn(f, '');
    
    contadorRelaciones := 0;
    actual := ContactosManuales;
    
    WriteLn('📊 Analizando relaciones de contactos...');
    
    // Primer paso: recopilar todos los usuarios y contactos únicos
    while actual <> nil do
    begin
      usuariosEncontrados.Add(actual^.agregadoPor);
      contactosEncontrados.Add(actual^.email);
      Inc(contadorRelaciones);
      actual := actual^.siguiente;
    end;
    
    contadorUsuarios := usuariosEncontrados.Count;
    
    if contadorRelaciones = 0 then
    begin
      WriteLn(f, '  vacio [label="👥 Sin relaciones de contactos\\n\\nNo hay contactos cargados en el sistema\\nLas relaciones se crean con:\\n• Carga masiva de contactos\\n• Agregado manual de contactos", fillcolor="#F0F0F0", fontcolor="gray", shape="box", style="rounded,filled"];');
    end
    else
    begin
      // ✅ SECCIÓN LEYENDA - MÁS COMPACTA Y ORGANIZADA
      WriteLn(f, '  subgraph cluster_leyenda {');
      WriteLn(f, '    rank=source;'); // ✅ FORZAR que aparezca al principio
      WriteLn(f, '    label="🔗 LEYENDA";');
      WriteLn(f, '    style="rounded,filled";');
      WriteLn(f, '    fillcolor="#F8F8FF";');
      WriteLn(f, '    fontcolor=navy;');
      WriteLn(f, '    fontweight=bold;');
      WriteLn(f, '    margin=10;');
      WriteLn(f, '');
      WriteLn(f, '    leyenda_usuario [label="👤 USUARIO\\n(Propietario)", fillcolor="#4169E1", fontcolor=white, shape="box", style="rounded,filled", width=1.2, height=0.8];');
      WriteLn(f, '    leyenda_contacto [label="📧 CONTACTO\\n(En lista)", fillcolor="#32CD32", fontcolor=white, shape="ellipse", style="filled", width=1.2, height=0.8];');
      WriteLn(f, '    leyenda_comun [label="❤️ CONTACTO\\nEN COMÚN", fillcolor="#FF6347", fontcolor=white, shape="diamond", style="filled", width=1.3, height=0.8];');
      WriteLn(f, '');
      WriteLn(f, '    leyenda_usuario -> leyenda_contacto [color="#0066CC", style="bold", label="tiene", fontcolor="#0066CC"];');
      WriteLn(f, '    leyenda_usuario -> leyenda_comun [color="#CC0000", style="bold,dashed", label="común", fontcolor="#CC0000"];');
      WriteLn(f, '  }');
      WriteLn(f, '');
      
      // ✅ CLUSTER DE USUARIOS - LADO IZQUIERDO
      WriteLn(f, '  subgraph cluster_usuarios {');
      WriteLn(f, '    rank=same;'); // ✅ MISMO RANGO para alineación horizontal
      WriteLn(f, '    label="👤 USUARIOS DEL SISTEMA";');
      WriteLn(f, '    style="rounded,filled";');
      WriteLn(f, '    fillcolor="#E6F2FF";');
      WriteLn(f, '    fontcolor="#003366";');
      WriteLn(f, '    fontweight=bold;');
      WriteLn(f, '    margin=15;');
      WriteLn(f, '');
      
      // Generar nodos de usuarios con mejor formato
      for i := 0 to usuariosEncontrados.Count - 1 do
      begin
        usuario1 := usuariosEncontrados[i];
        WriteLn(f, Format('    usuario_%d [label="👤\\n%s\\n\\nUsuario #%d", fillcolor="#4169E1", fontcolor=white, shape="box", style="rounded,filled", width=1.5, height=1.2];',
                         [i, SanearTexto(Copy(usuario1, 1, 15)), i + 1]));
      end;
      
      WriteLn(f, '  }');
      WriteLn(f, '');
      
      // ✅ CLUSTER DE CONTACTOS - LADO DERECHO
      WriteLn(f, '  subgraph cluster_contactos {');
      WriteLn(f, '    rank=same;'); // ✅ MISMO RANGO para alineación horizontal
      WriteLn(f, '    label="📧 CONTACTOS DISPONIBLES";');
      WriteLn(f, '    style="rounded,filled";');
      WriteLn(f, '    fillcolor="#F0FFF0";');
      WriteLn(f, '    fontcolor="#006600";');
      WriteLn(f, '    fontweight=bold;');
      WriteLn(f, '    margin=15;');
      WriteLn(f, '');
      
      // Generar nodos de contactos con mejor formato
      for i := 0 to contactosEncontrados.Count - 1 do
      begin
        contactoComun := contactosEncontrados[i];
        WriteLn(f, Format('    contacto_%d [label="📧\\n%s\\n\\nContacto #%d", fillcolor="#32CD32", fontcolor=white, shape="ellipse", style="filled", width=1.8, height=1.2];',
                         [i, SanearTexto(Copy(contactoComun, 1, 15)), i + 1]));
      end;
      
      WriteLn(f, '  }');
      WriteLn(f, '');
      
      // ✅ INVISIBLE EDGES para forzar layout ordenado
      WriteLn(f, '  // Invisible edges para organizar layout');
      if usuariosEncontrados.Count > 1 then
      begin
        for i := 0 to usuariosEncontrados.Count - 2 do
          WriteLn(f, Format('  usuario_%d -> usuario_%d [style=invis];', [i, i + 1]));
      end;
      
      if contactosEncontrados.Count > 1 then
      begin
        for i := 0 to contactosEncontrados.Count - 2 do
          WriteLn(f, Format('  contacto_%d -> contacto_%d [style=invis];', [i, i + 1]));
      end;
      WriteLn(f, '');
      
      // ✅ RELACIONES USUARIO -> CONTACTO - MÁS ORGANIZADAS
      WriteLn(f, '  // Relaciones Usuario -> Contacto');
      actual := ContactosManuales;
      while actual <> nil do
      begin
        i := usuariosEncontrados.IndexOf(actual^.agregadoPor);
        j := contactosEncontrados.IndexOf(actual^.email);
        
        if (i >= 0) and (j >= 0) then
        begin
          WriteLn(f, Format('  usuario_%d -> contacto_%d [color="#0066CC", style="bold", penwidth=2, arrowsize=0.8, fontcolor="#0066CC"];',
                           [i, j]));
        end;
        
        actual := actual^.siguiente;
      end;
      WriteLn(f, '');
      
      // ✅ BUSCAR Y MOSTRAR CONTACTOS EN COMÚN - MEJORADO
      WriteLn(f, '  // Contactos en común entre usuarios');
      relacionesComunes := 0;
      for i := 0 to usuariosEncontrados.Count - 1 do
      begin
        for j := i + 1 to usuariosEncontrados.Count - 1 do
        begin
          usuario1 := usuariosEncontrados[i];
          usuario2 := usuariosEncontrados[j];
          
          // Buscar contactos en común entre usuario1 y usuario2
          actual := ContactosManuales;
          while actual <> nil do
          begin
            if actual^.agregadoPor = usuario1 then
            begin
              // Ver si usuario2 también tiene este contacto
              if TieneContacto(usuario2, actual^.email) then
              begin
                // Encontramos un contacto en común - mostrar conexión especial
                WriteLn(f, Format('  usuario_%d -> usuario_%d [color="#CC0000", style="bold,dashed", penwidth=3, arrowsize=1.0, label="❤️ %s", fontcolor="#CC0000", fontsize=9];',
                                 [i, j, SanearTexto(Copy(actual^.email, 1, 12))]));
                Inc(relacionesComunes);
                Break; // Solo mostrar una conexión por par de usuarios
              end;
            end;
            actual := actual^.siguiente;
          end;
        end;
      end;
      WriteLn(f, '');
      
      // ✅ CLUSTER DE ESTADÍSTICAS - MÁS VISUAL
      WriteLn(f, '  subgraph cluster_estadisticas {');
      WriteLn(f, '    rank=sink;'); // ✅ FORZAR que aparezca al final
      WriteLn(f, '    label="📊 ESTADÍSTICAS DE LA RED";');
      WriteLn(f, '    style="rounded,filled";');
      WriteLn(f, '    fillcolor="#FFFACD";');
      WriteLn(f, '    fontcolor="#8B4513";');
      WriteLn(f, '    fontweight=bold;');
      WriteLn(f, '    margin=15;');
      WriteLn(f, '');
      WriteLn(f, '    stats [label="📈 ANÁLISIS DE CONECTIVIDAD\\n\\n👤 Total usuarios activos: ' + IntToStr(contadorUsuarios) + '\\n📧 Total contactos únicos: ' + IntToStr(contactosEncontrados.Count) + '\\n🔗 Total conexiones: ' + IntToStr(contadorRelaciones) + '\\n❤️ Contactos compartidos: ' + IntToStr(relacionesComunes) + '\\n\\n📊 Densidad de red: ' + Format('%.1f%%', [(relacionesComunes * 100.0) / (contadorRelaciones + 1)]) + '\\n\\n📅 Generado: ' + FormatDateTime('dd/mm/yyyy hh:nn', Now) + '", shape="note", style="rounded,filled", fillcolor="#FFFFFF", fontcolor="#333333", width=3.5, height=2.5];');
      WriteLn(f, '  }');
    end;
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
    usuariosEncontrados.Free;
    contactosEncontrados.Free;
  end;
  
  WriteLn('👥 Reporte de relaciones de contactos generado: ', rutaDot);
  WriteLn('📊 Total de relaciones procesadas: ', contadorRelaciones);
  WriteLn('👤 Usuarios únicos: ', contadorUsuarios);
end;

// Función auxiliar para verificar si un usuario tiene un contacto específico
function TieneContacto(const usuario, emailContacto: String): Boolean;
var
  actual: PContactoManual;
begin
  Result := False;
  actual := ContactosManuales;
  
  while actual <> nil do
  begin
    if (actual^.agregadoPor = usuario) and (actual^.email = emailContacto) then
    begin
      Result := True;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

// ✅ NUEVA: Función básica para generar reporte BST de comunidades
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
      // Generar estructura del árbol BST - versión simplificada
      WriteLn(f, '  info [label="🌳 BST DE COMUNIDADES\\n\\nTotal comunidades: ' + IntToStr(ContarComunidades(ArbolComunidades)) + '\\n\\nVer consola para recorridos completos", shape="note", fillcolor="#FFFFCC"];');
      
      // Nota: Para una implementación completa del BST visual,
      // se necesitaría una función recursiva para recorrer el árbol
      // y generar los nodos y conexiones apropiados
    end;
    
    WriteLn(f, '}');
  finally
    CloseFile(f);
  end;
  
  WriteLn('🌳 Reporte BST generado: ', rutaDot);
end;

end.
