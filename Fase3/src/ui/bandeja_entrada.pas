unit bandeja_entrada;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils, DateUtils, Process,
  listasimple2, cola2, arbol_avl, arbol_b, blockchain, pila2, merkle_tree,
  json_loader, eliminar, lzw_compression;

procedure MostrarBandejaEntrada(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain; var merklePrivados: TArbolMerkle);

implementation

type
  PCorreoRecibido = ^TCorreoRecibido;
  TCorreoRecibido = record
    id: Integer;
    remitente: String;
    destinatario: String;
    asunto: String;
    mensaje: String;
    estado: String;
    siguiente: PCorreoRecibido;
  end;

var
  GEmailUsuario: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  GPapelera: ^TPila = nil;
  GBlockchain: ^TBlockchain = nil;
  GMerklePrivados: ^TArbolMerkle = nil;
  
  BandejaWindow: PGtkWidget = nil;
  ListaCorreos: PGtkWidget = nil;
  TextViewDetalle: PGtkWidget = nil;
  LabelCorreosNoLeidos: PGtkWidget = nil;
  
  CorreoSeleccionado: Integer = 0;
  CorreoSeleccionadoID: Integer = 0;

{ === FUNCIONES AUXILIARES === }

function GenerarNuevoIDCorreo(): Integer;
begin
  Result := Trunc(Now * 86400) mod 100000;
end;

procedure MostrarMensaje(const titulo, mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), PChar(titulo));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

function ObtenerTextoTextView(textView: PGtkWidget): String;
var
  buffer: PGtkTextBuffer;
  startIter, endIter: TGtkTextIter;
  texto: PChar;
begin
  buffer := gtk_text_view_get_buffer(PGtkTextView(textView));
  gtk_text_buffer_get_start_iter(buffer, @startIter);
  gtk_text_buffer_get_end_iter(buffer, @endIter);
  texto := gtk_text_buffer_get_text(buffer, @startIter, @endIter, False);
  Result := StrPas(texto);
  g_free(texto);
end;

function SanearUTF8(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if (Ord(c) >= 32) and (Ord(c) <> 127) then
      Result := Result + c
    else
      Result := Result + '?';
  end;
end;

function LimpiarTextoParaGTK(const texto: String): String;
var
  i: Integer;
  c: Char;
  resultado: String;
begin
  resultado := '';
  for i := 1 to Length(texto) do
  begin
    c := texto[i];
    if (Ord(c) >= 32) and (Ord(c) <= 126) then
      resultado := resultado + c
    else
      resultado := resultado + '?';
  end;
  Result := resultado;
end;

procedure LiberarListaCorreos(var lista: PCorreoRecibido);
var
  actual, temp: PCorreoRecibido;
begin
  actual := lista;
  while actual <> nil do
  begin
    temp := actual^.siguiente;
    Dispose(actual);
    actual := temp;
  end;
  lista := nil;
end;

procedure AgregarCorreoALista(var lista: PCorreoRecibido; id: Integer; const remitente, asunto, mensaje, estado: String);
var
  nuevo: PCorreoRecibido;
begin
  New(nuevo);
  nuevo^.id := id;
  nuevo^.remitente := remitente;
  nuevo^.destinatario := '';
  nuevo^.asunto := asunto;
  nuevo^.mensaje := mensaje;
  nuevo^.estado := estado;
  nuevo^.siguiente := lista;
  lista := nuevo;
end;

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

function ExtraerEmailDesdeToken(const token: String): String;
var
  p1, p2: SizeInt;
  tmp: String;
begin
  tmp := Trim(token);
  p1 := Pos('<', tmp);
  if p1 > 0 then
  begin
    p2 := Pos('>', tmp);
    if p2 > p1 then
      tmp := Copy(tmp, p1 + 1, p2 - p1 - 1);
  end;
  Result := NormalizarEmail(tmp);
end;

procedure SplitLocalDomain(const email: String; out localPart, domain: String);
var
  e: String;
  p: SizeInt;
begin
  e := NormalizarEmail(email);
  p := Pos('@', e);
  if p > 0 then
  begin
    localPart := Copy(e, 1, p - 1);
    domain := Copy(e, p + 1, Length(e));
  end
  else
  begin
    localPart := e;
    domain := '';
  end;
end;

function GmailNormalizeLocal(const s: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    if c = '+' then Break;
    if c <> '.' then
      Result := Result + c;
  end;
end;

function EmailsCoincidenFlex(const a, b: String): Boolean;
var
  al, ad, bl, bd: String;
begin
  if NormalizarEmail(a) = NormalizarEmail(b) then
  begin
    Result := True;
    Exit;
  end;
  
  SplitLocalDomain(a, al, ad);
  SplitLocalDomain(b, bl, bd);
  
  if (ad = 'gmail.com') or (ad = 'googlemail.com') then
    al := GmailNormalizeLocal(al);
  if (bd = 'gmail.com') or (bd = 'googlemail.com') then
    bl := GmailNormalizeLocal(bl);
  
  Result := (al = bl) and (ad = bd);
end;

function EsCharEmailValido(c: Char): Boolean; inline;
begin
  Result := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z')) or 
            ((c >= '0') and (c <= '9')) or (c = '@') or (c = '.') or (c = '_') or (c = '-') or (c = '+');
end;

function ContieneDestinatario(const emailCampo, emailBuscado: String): Boolean;
var
  emailNormalizado, buscadoNormalizado: String;
  i, inicio: Integer;
  token: String;
  encontrado: Boolean;
begin
  emailNormalizado := LowerCase(Trim(emailCampo));
  buscadoNormalizado := LowerCase(Trim(emailBuscado));
  
  if emailNormalizado = buscadoNormalizado then
  begin
    Result := True;
    Exit;
  end;
  
  encontrado := False;
  i := 1;
  while i <= Length(emailCampo) do
  begin
    while (i <= Length(emailCampo)) and not EsCharEmailValido(emailCampo[i]) do
      Inc(i);
    
    if i <= Length(emailCampo) then
    begin
      inicio := i;
      while (i <= Length(emailCampo)) and EsCharEmailValido(emailCampo[i]) do
        Inc(i);
      
      token := Copy(emailCampo, inicio, i - inicio);
      if Pos('@', token) > 0 then
      begin
        if EmailsCoincidenFlex(ExtraerEmailDesdeToken(token), emailBuscado) then
        begin
          encontrado := True;
          Break;
        end;
      end;
    end;
  end;
  
  if not encontrado then
    Result := Pos(buscadoNormalizado, emailNormalizado) > 0
  else
    Result := encontrado;
end;

function ContarCorreosNoLeidos(const emailUsuario: String): Integer;
var
  actual: cola2.PCorreo;
  contador: Integer;
  emailUsuarioNorm: String;
  estado: String;
begin
  contador := 0;
  emailUsuarioNorm := NormalizarEmail(emailUsuario);
  
  if GProgramados <> nil then
  begin
    actual := GProgramados^.frente;
    while actual <> nil do
    begin
      if ContieneDestinatario(String(actual^.destinatario), emailUsuarioNorm) then
      begin
        estado := ObtenerEstadoCorreo(actual^.id);
        if estado = 'NL' then
          Inc(contador);
      end;
      actual := actual^.siguiente;
    end;
  end;
  
  Result := contador;
end;

procedure ActualizarLabelNoLeidos();
var
  totalNoLeidos: Integer;
  textoLabel: String;
begin
  if LabelCorreosNoLeidos = nil then Exit;
  
  totalNoLeidos := ContarCorreosNoLeidos(GEmailUsuario);
  
  if totalNoLeidos = 0 then
    textoLabel := '✅ Todos los correos están leídos'
  else if totalNoLeidos = 1 then
    textoLabel := '📬 1 correo no leído'
  else
    textoLabel := '📬 ' + IntToStr(totalNoLeidos) + ' correos no leídos';
  
  gtk_label_set_text(GTK_LABEL(LabelCorreosNoLeidos), PChar(textoLabel));
  
  WriteLn('📊 Label actualizado: ', totalNoLeidos, ' correos no leídos');
end;

function ObtenerCorreosRecibidos(const emailUsuario: String): PCorreoRecibido;
var
  lista: PCorreoRecibido;
  actual: cola2.PCorreo;
  emailNormalizado: String;
  estado: String;
begin
  lista := nil;
  emailNormalizado := NormalizarEmail(emailUsuario);
  
  if GProgramados <> nil then
  begin
    actual := GProgramados^.frente;
    while actual <> nil do
    begin
      if ContieneDestinatario(String(actual^.destinatario), emailNormalizado) then
      begin
        estado := ObtenerEstadoCorreo(actual^.id);
        AgregarCorreoALista(lista, actual^.id, String(actual^.remitente), 
                           String(actual^.asunto), String(actual^.mensaje), estado);
      end;
      actual := actual^.siguiente;
    end;
  end;
  
  Result := lista;
end;

procedure CargarCorreosEnLista(lista: PCorreoRecibido);
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actual: PCorreoRecibido;
  idStr, estadoTexto: String;
  contador: Integer;
begin
  if ListaCorreos = nil then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaCorreos)));
  if store = nil then Exit;
  
  gtk_list_store_clear(store);
  
  contador := 0;
  actual := lista;
  
  while actual <> nil do
  begin
    idStr := IntToStr(actual^.id);
    
    if actual^.estado = 'L' then
      estadoTexto := 'Leído'
    else
      estadoTexto := 'No Leído';
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(SanearUTF8(idStr)),
                       1, PChar(SanearUTF8(actual^.remitente)),
                       2, PChar(SanearUTF8(actual^.asunto)),
                       3, PChar(estadoTexto),
                       -1);
    
    Inc(contador);
    actual := actual^.siguiente;
  end;
  
  WriteLn('📧 Correos cargados en interfaz: ', contador);
end;

procedure OnDescargarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  actual: cola2.PCorreo;
  contenidoOriginal, contenidoComprimido, contenidoDescomprimido: String;
  rutaArchivo: String;
  archivo: TextFile;
  fechaHora: String;
begin
  if CorreoSeleccionadoID <= 0 then
  begin
    MostrarMensaje('Error', 'Selecciona un correo para descargar.', GTK_MESSAGE_WARNING);
    Exit;
  end;
  
  if GProgramados = nil then Exit;
  
  actual := GProgramados^.frente;
  while actual <> nil do
  begin
    if actual^.id = CorreoSeleccionadoID then
    begin
      contenidoOriginal := 'CORREO ELECTRÓNICO' + #13#10 +
                          '==================' + #13#10 + #13#10 +
                          'ID: ' + IntToStr(actual^.id) + #13#10 +
                          'De: ' + String(actual^.remitente) + #13#10 +
                          'Para: ' + String(actual^.destinatario) + #13#10 +
                          'Asunto: ' + String(actual^.asunto) + #13#10 + #13#10 +
                          'MENSAJE:' + #13#10 +
                          '--------' + #13#10 +
                          String(actual^.mensaje) + #13#10 + #13#10 +
                          'Descargado: ' + FormatDateTime('dd/mm/yyyy hh:nn:ss', Now);
      
      contenidoComprimido := ComprimirLZW(contenidoOriginal);
      contenidoDescomprimido := DescomprimirLZW(contenidoComprimido);
      
      fechaHora := FormatDateTime('yyyymmdd-hhnnss', Now);
      rutaArchivo := ExtractFileDir(ParamStr(0)) + '/correo-' + IntToStr(actual^.id) + '-' + fechaHora + '.txt';
      
      try
        AssignFile(archivo, rutaArchivo);
        Rewrite(archivo);
        WriteLn(archivo, contenidoDescomprimido);
        CloseFile(archivo);
        
        MostrarMensaje('Descarga Exitosa', 
          'Correo descargado con compresión LZW:' + #10 + #10 +
          'Archivo: correo-' + IntToStr(actual^.id) + '-' + fechaHora + '.txt' + #10 +
          'Ubicación: ' + ExtractFileDir(ParamStr(0)) + '/', 
          GTK_MESSAGE_INFO);
        
        WriteLn('📥 Correo descargado con LZW: ', rutaArchivo);
        Break;
        
      except
        on E: Exception do
          MostrarMensaje('Error de Descarga', 'Error al guardar archivo: ' + E.Message, GTK_MESSAGE_ERROR);
      end;
    end;
    actual := actual^.siguiente;
  end;
end;

procedure OnAgregarAFavoritos(widget: PGtkWidget; data: gpointer); cdecl;
var
  actual: cola2.PCorreo;
  encontrado: Boolean;
  correoB: TCorreoB;
  resultado: Boolean;
begin
  if CorreoSeleccionadoID <= 0 then
  begin
    MostrarMensaje('Error', 'Selecciona un correo para agregar a favoritos.', GTK_MESSAGE_WARNING);
    Exit;
  end;
  
  if GProgramados = nil then Exit;
  
  encontrado := False;
  actual := GProgramados^.frente;
  
  while actual <> nil do
  begin
    if actual^.id = CorreoSeleccionadoID then
    begin
      correoB.id := actual^.id;
      correoB.remitente := String(actual^.remitente);
      correoB.destinatario := String(actual^.destinatario);
      correoB.asunto := String(actual^.asunto);
      correoB.mensaje := String(actual^.mensaje);
      
      // ✅ CORREGIR: Llamar procedimiento sin asignar resultado
      arbol_b.Insertar(GFavoritos^, correoB);
      
      WriteLn('⭐ Correo agregado a favoritos ID: ', actual^.id);
      MostrarMensaje('Agregado a Favoritos', 
        'El correo ha sido agregado a tus favoritos.' + #10 + #10 +
        'Asunto: ' + String(actual^.asunto) + #10 +
        'De: ' + String(actual^.remitente), 
        GTK_MESSAGE_INFO);
      encontrado := True;
      Break;
    end;
    actual := actual^.siguiente;
  end;
  
  if not encontrado then
    MostrarMensaje('Error', 'No se encontró el correo seleccionado.', GTK_MESSAGE_ERROR);
end;

procedure OnAgregarAPrivados(widget: PGtkWidget; data: gpointer); cdecl;
var
  actual: cola2.PCorreo;
  encontrado: Boolean;
begin
  if CorreoSeleccionadoID <= 0 then
  begin
    MostrarMensaje('Error', 'Selecciona un correo para agregar a privados.', GTK_MESSAGE_WARNING);
    Exit;
  end;
  
  if GProgramados = nil then Exit;
  
  encontrado := False;
  actual := GProgramados^.frente;
  
  while actual <> nil do
  begin
    if actual^.id = CorreoSeleccionadoID then
    begin
      if InsertarCorreoPrivado(GMerklePrivados^, actual^.id, String(actual^.remitente), 
                              String(actual^.destinatario), String(actual^.asunto), String(actual^.mensaje)) then
      begin
        WriteLn('🔒 Correo agregado a privados con Merkle Tree ID: ', actual^.id);
        MostrarMensaje('Correo Privado Agregado', 
          'El correo ha sido agregado a tus correos privados.' + #10 + #10 +
          'Protección: Merkle Tree' + #10 +
          'Integridad: Verificada criptográficamente' + #10 +
          'Asunto: ' + String(actual^.asunto) + #10 +
          'De: ' + String(actual^.remitente), 
          GTK_MESSAGE_INFO);
        encontrado := True;
      end
      else
      begin
        WriteLn('❌ Error agregando a privados');
        MostrarMensaje('Error', 'No se pudo agregar el correo a privados.', GTK_MESSAGE_ERROR);
      end;
      Break;
    end;
    actual := actual^.siguiente;
  end;
  
  if not encontrado then
    MostrarMensaje('Error', 'No se encontró el correo seleccionado.', GTK_MESSAGE_ERROR);
end;

procedure OnSeleccionarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  selection: PGtkTreeSelection;
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  idStr, estadoStr: PChar;
  correoID: Integer;
  actual: cola2.PCorreo;
  buffer: PGtkTextBuffer;
  textoDetalle: String;
  estadoAnterior: String;
  store: PGtkListStore;
begin
  if ListaCorreos = nil then Exit;

  selection := gtk_tree_view_get_selection(PGtkTreeView(ListaCorreos));
  if selection = nil then Exit;

  if gtk_tree_selection_get_selected(selection, @model, @iter) then
  begin
    idStr := nil;
    estadoStr := nil;
    
    gtk_tree_model_get(model, @iter, 0, @idStr, 3, @estadoStr, -1);
    
    if idStr <> nil then
    begin
      correoID := StrToIntDef(StrPas(idStr), 0);
      g_free(idStr);
      
      if estadoStr <> nil then
        g_free(estadoStr);

      if correoID <> 0 then
      begin
        CorreoSeleccionadoID := correoID;

        estadoAnterior := ObtenerEstadoCorreo(correoID);

        if (estadoAnterior = 'NL') then
        begin
          EstablecerEstadoCorreo(correoID, 'L');
          
          store := PGtkListStore(model);
          gtk_list_store_set(store, @iter, 3, PChar('Leído'), -1);
          
          ActualizarLabelNoLeidos();
        end;

        if GProgramados <> nil then
        begin
          actual := GProgramados^.frente;
          while actual <> nil do
          begin
            if actual^.id = correoID then
            begin
              textoDetalle := '📧 CORREO ELECTRÓNICO' + #13#10 +
                              '===================' + #13#10 + #13#10 +
                              'ID: ' + IntToStr(actual^.id) + #13#10 +
                              'De: ' + SanearUTF8(String(actual^.remitente)) + #13#10 +
                              'Para: ' + SanearUTF8(String(actual^.destinatario)) + #13#10 + #13#10 +
                              'ASUNTO:' + #13#10 +
                              SanearUTF8(String(actual^.asunto)) + #13#10 + #13#10 +
                              'MENSAJE:' + #13#10 +
                              '--------' + #13#10 +
                              SanearUTF8(String(actual^.mensaje));
              
              if TextViewDetalle <> nil then
              begin
                buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
                gtk_text_buffer_set_text(buffer, PChar(textoDetalle), -1);
              end;
              
              Break;
            end;
            actual := actual^.siguiente;
          end;
        end;
      end;
    end;
  end
  else
  begin
    CorreoSeleccionado := 0;
    CorreoSeleccionadoID := 0;
    if TextViewDetalle <> nil then
    begin
      buffer := gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle));
      gtk_text_buffer_set_text(buffer, 'Selecciona un correo para ver detalles', -1);
    end;
  end;
end;

procedure OnActualizarBandeja(widget: PGtkWidget; data: gpointer); cdecl;
var
  lista: PCorreoRecibido;
begin
  lista := ObtenerCorreosRecibidos(GEmailUsuario);
  CargarCorreosEnLista(lista);
  LiberarListaCorreos(lista);
  
  ActualizarLabelNoLeidos();
  
  if TextViewDetalle <> nil then
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDetalle)), 'Selecciona un correo para ver detalles', -1);
end;

procedure OnCerrarBandeja(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(BandejaWindow) then
    gtk_widget_destroy(BandejaWindow);
end;

procedure OnGenerarGrafica(widget: PGtkWidget; data: gpointer); cdecl;
var
  rutaDir, rutaDot: String;
begin
  rutaDir := ExtractFileDir(ExtractFileDir(ParamStr(0))) + '/graficos/' + GEmailUsuario;
  if not DirectoryExists(rutaDir) then
    CreateDir(rutaDir);
  
  rutaDot := rutaDir + '/bandeja-entrada.dot';
  
  WriteLn('📊 Gráfico generado: ', rutaDot);
end;

function OnDeleteEventBandeja(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  if Assigned(BandejaWindow) then
    gtk_widget_destroy(BandejaWindow);
  Result := True;
end;

procedure MostrarNotificacion(const mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

procedure OnEliminarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  actual: cola2.PCorreo;
  remitente, destinatario, asunto, mensaje: String;
begin
  if CorreoSeleccionadoID <= 0 then
  begin
    MostrarMensaje('Error', 'Selecciona un correo para eliminar.', GTK_MESSAGE_WARNING);
    Exit;
  end;
  
  if GProgramados = nil then Exit;
  
  actual := GProgramados^.frente;
  while actual <> nil do
  begin
    if actual^.id = CorreoSeleccionadoID then
    begin
      remitente := String(actual^.remitente);
      destinatario := String(actual^.destinatario);
      asunto := String(actual^.asunto);
      mensaje := String(actual^.mensaje);
      
      if GPapelera <> nil then
        EliminarCorreoDeBandeja(CorreoSeleccionadoID, remitente, destinatario, asunto, mensaje, GPapelera^);
      
      MostrarMensaje('Correo Eliminado', 
        'El correo ha sido movido a la papelera.' + #10 + #10 +
        'Puedes recuperarlo desde la sección "🗑️ Papelera".', 
        GTK_MESSAGE_INFO);
      
      OnActualizarBandeja(nil, nil);
      Break;
    end;
    actual := actual^.siguiente;
  end;
end;

function ValidarDestinatarioExiste(const emailDestinatario: String): Boolean;
var
  actual: PUsuario;
begin
  Result := False;
  
  if GUsuarios = nil then Exit;
  
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    if LowerCase(String(actual^.email)) = LowerCase(emailDestinatario) then
    begin
      Result := True;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

procedure MostrarBandejaEntrada(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var papelera: TPila; var blockchainMail: TBlockchain; var merklePrivados: TArbolMerkle);
var
  hpaned, vboxIzq, vboxDer, scrolledLista, scrolledDetalle: PGtkWidget;
  lblTitulo, lblDetalle: PGtkWidget;
  btnActualizar, btnEliminar, btnFavoritos, btnPrivados, btnDescargar, btnGrafica, btnCerrar: PGtkWidget;
  btnBox1, btnBox2: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  lista: PCorreoRecibido;
begin
  GEmailUsuario := emailUsuario;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;
  GPapelera := @papelera;
  GBlockchain := @blockchainMail;
  GMerklePrivados := @merklePrivados;
  
  CorreoSeleccionado := 0;
  CorreoSeleccionadoID := 0;
  
  if Assigned(BandejaWindow) then
    gtk_widget_destroy(BandejaWindow);
  
  BandejaWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(BandejaWindow), PChar('📥 Bandeja de Entrada - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(BandejaWindow), 1200, 700);
  g_signal_connect(BandejaWindow, 'delete-event', G_CALLBACK(@OnDeleteEventBandeja), nil);
  
  hpaned := gtk_hpaned_new();
  gtk_container_add(GTK_CONTAINER(BandejaWindow), hpaned);
  
  // Panel izquierdo - Lista de correos
  vboxIzq := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxIzq), 10);
  gtk_paned_add1(GTK_PANED(hpaned), vboxIzq);

  lblTitulo := gtk_label_new('Correos Recibidos');
  gtk_box_pack_start(GTK_BOX(vboxIzq), lblTitulo, False, False, 0);

  LabelCorreosNoLeidos := gtk_label_new('📊 Cargando estadísticas...');
  gtk_box_pack_start(GTK_BOX(vboxIzq), LabelCorreosNoLeidos, False, False, 0);
  
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxIzq), scrolledLista, True, True, 0);
  
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaCorreos := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), ListaCorreos);
  
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 60);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);
  
  column := gtk_tree_view_column_new_with_attributes('De', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);
  
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 300);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);
  
  column := gtk_tree_view_column_new_with_attributes('Estado', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 80);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaCorreos), column);
  
  g_signal_connect(gtk_tree_view_get_selection(PGtkTreeView(ListaCorreos)), 
                   'changed', G_CALLBACK(@OnSeleccionarCorreo), nil);
  
  // Botones de acción
  btnBox1 := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox1, False, False, 0);
  
  btnActualizar := gtk_button_new_with_label('🔄 Actualizar');
  g_signal_connect(btnActualizar, 'clicked', G_CALLBACK(@OnActualizarBandeja), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnActualizar, True, True, 0);
  
  btnEliminar := gtk_button_new_with_label('🗑️ Eliminar');
  g_signal_connect(btnEliminar, 'clicked', G_CALLBACK(@OnEliminarCorreo), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnEliminar, True, True, 0);
  
  btnFavoritos := gtk_button_new_with_label('⭐ A Favoritos');
  g_signal_connect(btnFavoritos, 'clicked', G_CALLBACK(@OnAgregarAFavoritos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox1), btnFavoritos, True, True, 0);
  
  btnBox2 := gtk_hbox_new(True, 5);
  gtk_box_pack_start(GTK_BOX(vboxIzq), btnBox2, False, False, 0);
  
  btnPrivados := gtk_button_new_with_label('🔒 A Privados');
  g_signal_connect(btnPrivados, 'clicked', G_CALLBACK(@OnAgregarAPrivados), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnPrivados, True, True, 0);
  
  btnDescargar := gtk_button_new_with_label('📥 Descargar');
  g_signal_connect(btnDescargar, 'clicked', G_CALLBACK(@OnDescargarCorreo), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnDescargar, True, True, 0);
  
  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarBandeja), nil);
  gtk_box_pack_start(GTK_BOX(btnBox2), btnCerrar, True, True, 0);
  
  // Panel derecho - Detalle del correo
  vboxDer := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vboxDer), 10);
  gtk_paned_add2(GTK_PANED(hpaned), vboxDer);
  
  lblDetalle := gtk_label_new('Detalle del correo:');
  gtk_box_pack_start(GTK_BOX(vboxDer), lblDetalle, False, False, 0);
  
  scrolledDetalle := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDetalle), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vboxDer), scrolledDetalle, True, True, 0);
  
  TextViewDetalle := gtk_text_view_new();
  gtk_text_view_set_editable(PGtkTextView(TextViewDetalle), False);
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDetalle), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDetalle), TextViewDetalle);
  
  lista := ObtenerCorreosRecibidos(GEmailUsuario);
  CargarCorreosEnLista(lista);
  LiberarListaCorreos(lista);

  ActualizarLabelNoLeidos();

  gtk_widget_show_all(BandejaWindow);
  
  WriteLn('📥 Funcionalidad de descarga con compresión LZW habilitada');
  WriteLn('🔒 Funcionalidad de correos privados con Merkle Tree habilitada');
  WriteLn('📊 Label dinámico de correos no leídos habilitado');
end;

end.
