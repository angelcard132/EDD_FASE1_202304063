unit programados;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils, DateUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader, blockchain;

procedure MostrarProgramados(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var blockchainMail: TBlockchain);

implementation

var
  GEmailUsuario: String;
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  GBlockchain: ^TBlockchain = nil; // Add blockchain reference
  
  ProgramadosWindow: PGtkWidget = nil;
  FormularioWindow: PGtkWidget = nil;
  VistaWindow: PGtkWidget = nil;

{ === FUNCIONES AUXILIARES === }

function GenerarNuevoIDCorreo(): Integer;
begin
  // ✅ GENERAR SIEMPRE IDs POSITIVOS usando timestamp + offset específico para programados
  Result := Abs(Trunc(Now * 86400)) mod 30000 + 20000; // Rango: 20000-49999
  if Result <= 0 then
    Result := 20000 + Random(29999); // Fallback con random positivo
    
  WriteLn('🔧 DEBUG: ID generado en programados: ', Result);
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

{ === FORMULARIO PROGRAMAR CORREO === }

var
  EntryDestinatario: PGtkWidget = nil;
  EntryAsunto: PGtkWidget = nil;
  TextViewMensaje: PGtkWidget = nil;
  EntryFecha: PGtkWidget = nil;

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

function ValidarDestinatarioExiste(const emailDestinatario: String): Boolean;
var
  actual: PUsuario;
begin
  Result := False;
  
  if GUsuarios = nil then Exit;
  
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    if LowerCase(actual^.email) = LowerCase(emailDestinatario) then
    begin
      Result := True;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

function ObtenerNombreContactoPorEmail(const emailDestinatario: String): String;
var
  actual: PUsuario;
begin
  Result := emailDestinatario; // Por defecto retornar el email
  
  if GUsuarios = nil then Exit;
  
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    if LowerCase(actual^.email) = LowerCase(emailDestinatario) then
    begin
      Result := actual^.nombre;
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

procedure OnProgramarCorreo(widget: PGtkWidget; data: gpointer); cdecl;
var
  destinatario, asunto, mensaje: String;
  nuevoID: Integer;
  nombreContacto: String;
begin
  destinatario := StrPas(gtk_entry_get_text(PGtkEntry(EntryDestinatario)));
  asunto := StrPas(gtk_entry_get_text(PGtkEntry(EntryAsunto)));
  mensaje := ObtenerTextoTextView(TextViewMensaje);

  // Validaciones básicas
  if (destinatario = '') or (asunto = '') or (mensaje = '') then
  begin
    MostrarMensaje('Error de Validación', 'Todos los campos son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Pos('@', destinatario) = 0 then
  begin
    MostrarMensaje('Error de Validación', 'El email del destinatario debe contener @.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // NUEVA VALIDACIÓN: Verificar que el destinatario existe
  if not ValidarDestinatarioExiste(destinatario) then
  begin
    nombreContacto := destinatario;
    MostrarMensaje('Contacto No Encontrado', 
      'El destinatario "' + nombreContacto + '" no existe en tu lista de contactos.' + LineEnding + LineEnding +
      'Para programar correos debes:' + LineEnding +
      '1. Ir a "👥 Agregar Contacto" y registrar este email, o' + LineEnding +
      '2. Pedirle al administrador que haga una carga masiva incluyendo este usuario' + LineEnding + LineEnding +
      'Solo puedes enviar correos a contactos que estén registrados en el sistema.', 
      GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Si el destinatario existe, obtener su nombre para mostrar confirmación
  nombreContacto := ObtenerNombreContactoPorEmail(destinatario);

  // Programar correo (no enviar inmediatamente)
  nuevoID := GenerarNuevoIDCorreo();
  Encolar(GProgramados^, nuevoID, GEmailUsuario, destinatario, asunto, mensaje);
  EstablecerEstadoCorreo(nuevoID, 'PROGRAMADO_MANUAL'); // ✅ Estado especial para programados MANUALES
  
  WriteLn('📅 Correo programado manualmente para: ', destinatario, ' con ID: ', nuevoID);
  
  MostrarMensaje('Correo Programado', 
    'El correo ha sido programado exitosamente.' + LineEnding + LineEnding +
    'Para: ' + nombreContacto + ' (' + destinatario + ')' + LineEnding +
    'Asunto: ' + asunto + LineEnding + LineEnding +
    'Ve a "Ver Programados" para enviarlo cuando desees.', 
    GTK_MESSAGE_INFO);
  
  // Cerrar formulario
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);
end;

procedure OnEnviarAhora(widget: PGtkWidget; data: gpointer); cdecl;
var
  destinatario, asunto, mensaje: String;
  nuevoID: Integer;
  nombreContacto: String;
begin
  destinatario := StrPas(gtk_entry_get_text(PGtkEntry(EntryDestinatario)));
  asunto := StrPas(gtk_entry_get_text(PGtkEntry(EntryAsunto)));
  mensaje := ObtenerTextoTextView(TextViewMensaje);

  // Validaciones básicas
  if (destinatario = '') or (asunto = '') or (mensaje = '') then
  begin
    MostrarMensaje('Error de Validación', 'Todos los campos son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  if Pos('@', destinatario) = 0 then
  begin
    MostrarMensaje('Error de Validación', 'El email del destinatario debe contener @.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // NUEVA VALIDACIÓN: Verificar que el destinatario existe
  if not ValidarDestinatarioExiste(destinatario) then
  begin
    nombreContacto := destinatario;
    MostrarMensaje('Contacto No Encontrado', 
      'El destinatario "' + nombreContacto + '" no existe en tu lista de contactos.' + LineEnding + LineEnding +
      'Para enviar correos debes:' + LineEnding +
      '1. Ir a "👥 Agregar Contacto" y registrar este email, o' + LineEnding +
      '2. Pedirle al administrador que haga una carga masiva incluyendo este usuario' + LineEnding + LineEnding +
      'Solo puedes enviar correos a contactos que estén registrados en el sistema.', 
      GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Si el destinatario existe, obtener su nombre para mostrar confirmación
  nombreContacto := ObtenerNombreContactoPorEmail(destinatario);

  // Enviar correo inmediatamente a la cola
  nuevoID := GenerarNuevoIDCorreo();
  Encolar(GProgramados^, nuevoID, GEmailUsuario, destinatario, asunto, mensaje);
  EstablecerEstadoCorreo(nuevoID, 'NL'); // No leído
  
  // NUEVO: Registrar en blockchain
  if GBlockchain <> nil then
  begin
    WriteLn('🔗 Registrando correo inmediato en blockchain...');
    RegistrarCorreoEnBlockchain(GBlockchain^, nuevoID, GEmailUsuario, destinatario, asunto, mensaje);
  end;
  
  WriteLn('✅ Correo enviado inmediatamente a: ', destinatario);
  
  MostrarMensaje('Correo Enviado', 
    'El correo ha sido enviado inmediatamente.' + LineEnding + LineEnding +
    'Para: ' + nombreContacto + ' (' + destinatario + ')' + LineEnding +
    'Asunto: ' + asunto + LineEnding + LineEnding +
    'Se ha registrado en la blockchain.', 
    GTK_MESSAGE_INFO);
  
  // Cerrar formulario
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);
end;

procedure OnGuardarBorradorProgramado(widget: PGtkWidget; data: gpointer); cdecl;
var
  destinatario, asunto, mensaje: String;
  nuevoID: Integer;
begin
  destinatario := StrPas(gtk_entry_get_text(PGtkEntry(EntryDestinatario)));
  asunto := StrPas(gtk_entry_get_text(PGtkEntry(EntryAsunto)));
  mensaje := ObtenerTextoTextView(TextViewMensaje);

  // Validaciones básicas
  if (destinatario = '') and (asunto = '') and (mensaje = '') then
  begin
    MostrarMensaje('Borrador Vacío', 'No hay contenido para guardar como borrador.', GTK_MESSAGE_WARNING);
    Exit;
  end;

  // ✅ GENERAR ID POSITIVO CON OFFSET ESPECÍFICO Y VERIFICACIÓN
  nuevoID := Abs(Trunc(Now * 86400)) mod 20000 + 30000; // Rango: 30000-49999 para programados->borradores
  if nuevoID <= 0 then
    nuevoID := 30000 + Random(19999); // Fallback específico
    
  WriteLn('🔧 DEBUG: ID borrador desde programados: ', nuevoID);
    
  GBorradores^ := arbol_avl.Insertar(GBorradores^, nuevoID, GEmailUsuario, destinatario, asunto, mensaje);
  
  WriteLn('✅ Borrador guardado desde programar correo ID: ', nuevoID, ' (POSITIVO GARANTIZADO)');
  
  MostrarMensaje('Borrador Guardado', 
    'El borrador ha sido guardado exitosamente.' + LineEnding + 
    'Para: ' + destinatario + LineEnding +
    'Asunto: ' + asunto + LineEnding + LineEnding +
    'ID generado: ' + IntToStr(nuevoID) + LineEnding +
    'Puedes editarlo y enviarlo desde el gestor de borradores.', 
    GTK_MESSAGE_INFO);
  
  // Cerrar ventana de programar
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);
end;

procedure OnRegresarFormulario(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);
end;

function OnDeleteEventFormulario(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando formulario programar...');
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);
  Result := True; // Prevenir cierre de aplicación
end;

procedure MostrarFormularioProgramar();
var
  vbox, form, hbox, btnBox, scrolledWindow: PGtkWidget;
  lblTitulo, lblPara, lblAsunto, lblMensaje, lblFecha: PGtkWidget;
  btnProgramar, btnBorrador, btnRegresar: PGtkWidget;
begin
  if Assigned(FormularioWindow) then
    gtk_widget_destroy(FormularioWindow);

  FormularioWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(FormularioWindow), PChar('📅 Programar Correo - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(FormularioWindow), 500, 450);
  gtk_window_set_position(GTK_WINDOW(FormularioWindow), GTK_WIN_POS_CENTER);

  // Conectar delete-event para prevenir cierre de aplicación
  g_signal_connect(FormularioWindow, 'delete-event', G_CALLBACK(@OnDeleteEventFormulario), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(FormularioWindow), vbox);

  lblTitulo := gtk_label_new(PChar('📧 Programar Nuevo Correo - De: ' + GEmailUsuario));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  form := gtk_vbox_new(False, 12);
  gtk_box_pack_start(GTK_BOX(vbox), form, True, True, 0);

  // Destinatario
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblPara := gtk_label_new('Para:');
  gtk_widget_set_size_request(lblPara, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblPara, False, False, 0);
  EntryDestinatario := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryDestinatario, True, True, 0);

  // Asunto
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblAsunto := gtk_label_new('Asunto:');
  gtk_widget_set_size_request(lblAsunto, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblAsunto, False, False, 0);
  EntryAsunto := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox), EntryAsunto, True, True, 0);

  // Fecha (por ahora solo informativo)
  hbox := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(form), hbox, False, False, 0);
  lblFecha := gtk_label_new('Fecha:');
  gtk_widget_set_size_request(lblFecha, 80, -1);
  gtk_box_pack_start(GTK_BOX(hbox), lblFecha, False, False, 0);
  EntryFecha := gtk_entry_new();
  gtk_entry_set_text(PGtkEntry(EntryFecha), PChar(FormatDateTime('dd/mm/yyyy hh:nn', Now)));
  gtk_widget_set_sensitive(EntryFecha, False); // Solo lectura por ahora
  gtk_box_pack_start(GTK_BOX(hbox), EntryFecha, True, True, 0);

  // Mensaje
  lblMensaje := gtk_label_new('Mensaje:');
  gtk_box_pack_start(GTK_BOX(form), lblMensaje, False, False, 0);

  scrolledWindow := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledWindow), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledWindow, -1, 150);
  gtk_box_pack_start(GTK_BOX(form), scrolledWindow, True, True, 0);

  TextViewMensaje := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensaje), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledWindow), TextViewMensaje);

  // Botones - cambiar funcionalidad del primer botón
  btnBox := gtk_hbox_new(True, 10);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnProgramar := gtk_button_new_with_label('📅 Programar Correo');
  g_signal_connect(btnProgramar, 'clicked', G_CALLBACK(@OnProgramarCorreo), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnProgramar, True, True, 0);

  btnBorrador := gtk_button_new_with_label('📝 Guardar Borrador');
  g_signal_connect(btnBorrador, 'clicked', G_CALLBACK(@OnGuardarBorradorProgramado), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnBorrador, True, True, 0);

  btnRegresar := gtk_button_new_with_label('🔙 Regresar');
  g_signal_connect(btnRegresar, 'clicked', G_CALLBACK(@OnRegresarFormulario), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnRegresar, True, True, 0);

  gtk_widget_show_all(FormularioWindow);
end;

{ === VISTA DE PROGRAMADOS === }

// Forward declaration
procedure MostrarVistaProgramados(); forward;

function OnDeleteEventVista(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando vista programados...');
  if Assigned(VistaWindow) then
    gtk_widget_destroy(VistaWindow);
  Result := True; // Prevenir cierre de aplicación  
end;

procedure OnEnviarTodos(widget: PGtkWidget; data: gpointer); cdecl;
var
  actual: PCorreo;
  contador: Integer;
  estadoCorreo: String;
begin
  contador := 0;
  actual := GProgramados^.frente;
  
  while actual <> nil do
  begin
    estadoCorreo := ObtenerEstadoCorreo(actual^.id);
    
    // ✅ SOLO enviar correos con estado PROGRAMADO_MANUAL
    if estadoCorreo = 'PROGRAMADO_MANUAL' then
    begin
      EstablecerEstadoCorreo(actual^.id, 'NL'); // Cambiar a "No Leído" (enviado)
      
      // Registrar en blockchain cuando se envía
      if GBlockchain <> nil then
      begin
        WriteLn('🔗 Registrando correo programado manual en blockchain...');
        RegistrarCorreoEnBlockchain(GBlockchain^, actual^.id, String(actual^.remitente), 
                                   String(actual^.destinatario), String(actual^.asunto), String(actual^.mensaje));
      end;
      
      Inc(contador);
      WriteLn('📤 Enviado correo programado manual ID: ', actual^.id, ' - ', String(actual^.asunto));
    end;
    actual := actual^.siguiente;
  end;
  
  if contador > 0 then
  begin
    MostrarMensaje('Correos Enviados', 
      'Se enviaron exitosamente ' + IntToStr(contador) + ' correos programados manualmente.' + LineEnding + LineEnding +
      'Los correos ahora aparecerán en las bandejas de los destinatarios y se han registrado en la blockchain.',
      GTK_MESSAGE_INFO);
    
    // Actualizar vista
    MostrarVistaProgramados();
  end
  else
    MostrarMensaje('Sin Correos', 'No hay correos programados manualmente para enviar.', GTK_MESSAGE_WARNING);
end;

procedure MostrarVistaProgramados();
var
  vbox, scrolledWindow, btnBox: PGtkWidget;
  lblTitulo, lblInfo: PGtkWidget;
  treeView: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  btnEnviarTodos, btnCerrar: PGtkWidget;
  actual: PCorreo;
  idStr: String;
  contadorProgramados: Integer;
  btnLabel: String;
  estadoCorreo: String;
begin
  if Assigned(VistaWindow) then
    gtk_widget_destroy(VistaWindow);

  VistaWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(VistaWindow), PChar('📋 Correos Programados - EDDMail'));
  gtk_window_set_default_size(GTK_WINDOW(VistaWindow), 900, 600);
  gtk_window_set_position(GTK_WINDOW(VistaWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(VistaWindow, 'delete-event', G_CALLBACK(@OnDeleteEventVista), nil);

  vbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 15);
  gtk_container_add(GTK_CONTAINER(VistaWindow), vbox);

  lblTitulo := gtk_label_new('📋 Correos Programados Manualmente');
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  lblInfo := gtk_label_new('Solo correos que TÚ programaste desde la interfaz. Los correos de carga masiva NO aparecen aquí.');
  gtk_box_pack_start(GTK_BOX(vbox), lblInfo, False, False, 0);

  // Lista de correos
  scrolledWindow := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledWindow), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vbox), scrolledWindow, True, True, 0);

  store := gtk_list_store_new(5, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeView := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledWindow), treeView);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('ID', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 60);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('De', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Para', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 180);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 250);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Mensaje', renderer, 'text', 4, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  // ✅ BUSCAR CORREOS PROGRAMADOS MANUALMENTE - MEJORADO
  contadorProgramados := 0;
  
  WriteLn('🔍 Buscando correos programados MANUALMENTE por usuario: ', GEmailUsuario);
  WriteLn('🔍 DEBUG: Estado de GProgramados: ', Assigned(GProgramados));
  
  if GProgramados <> nil then
  begin
    WriteLn('🔍 DEBUG: GProgramados asignado, estado frente: ', Assigned(GProgramados^.frente));
    
    if GProgramados^.frente <> nil then
    begin
      actual := GProgramados^.frente;
      while actual <> nil do
      begin
        // ✅ VERIFICAR TANTO remitente como destinatario para filtrar por usuario
        if (actual^.remitente = GEmailUsuario) or (actual^.destinatario = GEmailUsuario) then
        begin
          estadoCorreo := ObtenerEstadoCorreo(actual^.id);
          WriteLn('🔍 DEBUG: Correo ID ', actual^.id, ' del usuario encontrado, estado: "', estadoCorreo, '"');
          
          // ✅ MOSTRAR si tiene estado PROGRAMADO_MANUAL
          if estadoCorreo = 'PROGRAMADO_MANUAL' then
          begin
            idStr := IntToStr(actual^.id);
            
            gtk_list_store_append(store, @iter);
            gtk_list_store_set(store, @iter,
                               0, PChar(idStr),
                               1, PChar(String(actual^.remitente)),
                               2, PChar(String(actual^.destinatario)),
                               3, PChar(String(actual^.asunto)),
                               4, PChar(String(actual^.mensaje)),
                               -1);
            
            Inc(contadorProgramados);
            WriteLn('✅ DEBUG: Correo programado manual agregado: ID ', actual^.id, ' - ', actual^.asunto);
          end
          else
            WriteLn('🔍 DEBUG: Estado del correo no es PROGRAMADO_MANUAL: "', estadoCorreo, '"');
        end
        else
          WriteLn('🔍 DEBUG: Correo ID ', actual^.id, ' no es del usuario (De: ', actual^.remitente, ', Para: ', actual^.destinatario, ')');
        
        actual := actual^.siguiente;
      end;
    end
    else
      WriteLn('🔍 DEBUG: Cola vacía (frente = nil)');
  end
  else
    WriteLn('❌ DEBUG: GProgramados es nil');

  WriteLn('📊 DEBUG: Total correos programados MANUALMENTE encontrados: ', contadorProgramados);

  // Botones de acción
  btnBox := gtk_hbox_new(True, 10);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnLabel := '📤 Enviar Todos (' + IntToStr(contadorProgramados) + ')';
  btnEnviarTodos := gtk_button_new_with_label(PChar(btnLabel));
  g_signal_connect(btnEnviarTodos, 'clicked', G_CALLBACK(@OnEnviarTodos), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnEnviarTodos, True, True, 0);

  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@gtk_widget_destroy), VistaWindow);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, True, 0);

  gtk_widget_show_all(VistaWindow);
  
  WriteLn('📋 Vista programados cargada - Total programados: ', contadorProgramados);
end;

{ === INTERFAZ PRINCIPAL === }

procedure OnProgramarCorreoFormulario(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarFormularioProgramar();
end;

procedure OnVerListaProgramados(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarVistaProgramados();
end;

procedure OnCerrarProgramados(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(ProgramadosWindow) then
    gtk_widget_destroy(ProgramadosWindow);
end;

function OnDeleteEventProgramados(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando ventana programados...');
  if Assigned(ProgramadosWindow) then
    gtk_widget_destroy(ProgramadosWindow);
  Result := True; // Prevenir cierre de aplicación
end;

procedure MostrarProgramados(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB; var blockchainMail: TBlockchain);
var
  vbox, btnBox: PGtkWidget;
  lblTitulo, lblInfo: PGtkWidget;
  btnProgramar, btnVer, btnCerrar: PGtkWidget;
begin
  // Guardar referencias globales
  GEmailUsuario := emailUsuario;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;
  GBlockchain := @blockchainMail; // Add blockchain reference

  if Assigned(ProgramadosWindow) then
    gtk_widget_destroy(ProgramadosWindow);

  ProgramadosWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(ProgramadosWindow), PChar('📅 Gestión de Correos Programados'));
  gtk_window_set_default_size(GTK_WINDOW(ProgramadosWindow), 400, 300);
  gtk_window_set_position(GTK_WINDOW(ProgramadosWindow), GTK_WIN_POS_CENTER);

  // Conectar delete-event para prevenir cierre de aplicación
  g_signal_connect(ProgramadosWindow, 'delete-event', G_CALLBACK(@OnDeleteEventProgramados), nil);

  vbox := gtk_vbox_new(False, 20);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 30);
  gtk_container_add(GTK_CONTAINER(ProgramadosWindow), vbox);

  lblTitulo := gtk_label_new(PChar('📅 Correos Programados'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  lblInfo := gtk_label_new(PChar('Usuario: ' + emailUsuario));
  gtk_box_pack_start(GTK_BOX(vbox), lblInfo, False, False, 0);

  // Botones principales
  btnBox := gtk_vbox_new(False, 15);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, True, True, 0);

  btnProgramar := gtk_button_new_with_label('📧 Programar Correo');
  gtk_widget_set_size_request(btnProgramar, 250, 50);
  g_signal_connect(btnProgramar, 'clicked', G_CALLBACK(@OnProgramarCorreoFormulario), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnProgramar, True, False, 0);

  btnVer := gtk_button_new_with_label('📋 Ver Programados');
  gtk_widget_set_size_request(btnVer, 250, 50);
  g_signal_connect(btnVer, 'clicked', G_CALLBACK(@OnVerListaProgramados), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnVer, True, False, 0);

  btnCerrar := gtk_button_new_with_label('🔙 Regresar');
  gtk_widget_set_size_request(btnCerrar, 250, 50);
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarProgramados), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, True, False, 0);

  gtk_widget_show_all(ProgramadosWindow);
end;

end.
