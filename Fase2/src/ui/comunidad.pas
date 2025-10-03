unit comunidad;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader, arbolbst;

var
  ArbolComunidades: PNodoComunidadBST = nil; // BST global de comunidades
  MisComunidadesWindow: PGtkWidget = nil;
  OnComunidadCreada: procedure = nil; // Callback para notificar cuando se crea una comunidad

procedure MostrarGestionComunidades(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
procedure MostrarMisComunidades(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
procedure InicializarComunidades();
function ObtenerListaComunidades(): String;
function GenerarIDComunidad(): Integer;

implementation

var
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  
  ComunidadWindow: PGtkWidget = nil;
  ContadorIDComunidad: Integer = 1000;

{ === FUNCIONES DE ÁRBOL BST === }

procedure InicializarComunidades();
begin
  InicializarBST(ArbolComunidades);
  ContadorIDComunidad := 1000;
  WriteLn('🌳 Árbol BST de comunidades inicializado');
end;

function GenerarIDComunidad(): Integer;
begin
  Inc(ContadorIDComunidad);
  Result := ContadorIDComunidad;
end;

// Callback para recolectar comunidades en una lista
procedure CallbackRecolectarComunidades(comunidad: PNodoComunidadBST; data: Pointer);
var
  lista: ^String;
begin
  if (comunidad <> nil) and (data <> nil) then
  begin
    lista := PPointer(data)^;
    if lista^ <> '' then
      lista^ := lista^ + '|';
    lista^ := lista^ + comunidad^.nombre + ' (ID: ' + IntToStr(comunidad^.id) + ')';
  end;
end;

function ObtenerListaComunidades(): String;
var
  resultado: String;
  pResultado: Pointer;
begin
  resultado := '';
  pResultado := @resultado;
  
  RecorridoPersonalizadoBST(ArbolComunidades, @CallbackRecolectarComunidades, @pResultado);
  
  if resultado = '' then
    resultado := 'No hay comunidades creadas';
    
  Result := resultado;
end;

// Callback para buscar comunidades del usuario
procedure CallbackBuscarComunidadesUsuario(comunidad: PNodoComunidadBST; data: Pointer);
type
  TDatosBusqueda = record
    emailUsuario: String;
    resultado: String;
  end;
  PDatosBusqueda = ^TDatosBusqueda;
var
  datos: PDatosBusqueda;
  actualMensaje: PMensajeComunidad;
  esMiembro: Boolean;
begin
  if (comunidad = nil) or (data = nil) then Exit;
  
  datos := PDatosBusqueda(data);
  esMiembro := False;
  
  // Buscar si el usuario ha publicado mensajes en esta comunidad
  actualMensaje := comunidad^.mensajes;
  while actualMensaje <> nil do
  begin
    if LowerCase(actualMensaje^.correo) = LowerCase(datos^.emailUsuario) then
    begin
      esMiembro := True;
      Break;
    end;
    actualMensaje := actualMensaje^.siguiente;
  end;
  
  if esMiembro then
  begin
    if datos^.resultado <> '' then
      datos^.resultado := datos^.resultado + '|';
    datos^.resultado := datos^.resultado + comunidad^.nombre;
  end;
end;

function ObtenerComunidadesDelUsuario(const email: String): String;
var
  datos: record
    emailUsuario: String;
    resultado: String;
  end;
begin
  datos.emailUsuario := email;
  datos.resultado := '';
  
  RecorridoPersonalizadoBST(ArbolComunidades, @CallbackBuscarComunidadesUsuario, @datos);
  
  Result := datos.resultado;
end;

// Callback para recolectar comunidades que el usuario puede ver
procedure CallbackRecolectarComunidadesUsuario(comunidad: PNodoComunidadBST; data: Pointer);
type
  TDatosRecoleccion = record
    emailUsuario: String;
    resultado: String;
  end;
  PDatosRecoleccion = ^TDatosRecoleccion;
var
  datos: PDatosRecoleccion;
  nombreCompleto: String;
begin
  if (comunidad = nil) or (data = nil) then Exit;
  
  datos := PDatosRecoleccion(data);
  
  if PuedeMostrarComunidad(comunidad, datos^.emailUsuario) then
  begin
    if datos^.resultado <> '' then
      datos^.resultado := datos^.resultado + '|';
    
    // Formato mejorado para subcomunidades: "padre - subcomunidad"
    if comunidad^.esSubcomunidad and (comunidad^.comunidadPadre <> nil) then
      nombreCompleto := comunidad^.comunidadPadre^.nombre + ' - ' + comunidad^.nombre + ' (ID: ' + IntToStr(comunidad^.id) + ')'
    else
      nombreCompleto := comunidad^.nombre + ' (ID: ' + IntToStr(comunidad^.id) + ')';
    
    datos^.resultado := datos^.resultado + nombreCompleto;
    
    // Debug: Mostrar lo que se está agregando
    WriteLn('🔍 Debug - Agregando a combo: "', nombreCompleto, '"');
  end;
end;

function ObtenerComunidadesParaUsuario(const emailUsuario: String): String;
var
  datos: record
    emailUsuario: String;
    resultado: String;
  end;
begin
  datos.emailUsuario := emailUsuario;
  datos.resultado := '';
  
  RecorridoPersonalizadoBST(ArbolComunidades, @CallbackRecolectarComunidadesUsuario, @datos);
  
  if datos.resultado = '' then
    datos.resultado := 'No hay comunidades disponibles';
    
  Result := datos.resultado;
end;

{ === FUNCIONES AUXILIARES === }

procedure MostrarMensaje(const titulo, mensaje: String; tipoMensaje: TGtkMessageType);
var
  dialog: PGtkWidget;
begin
  dialog := gtk_message_dialog_new(nil, GTK_DIALOG_MODAL, tipoMensaje, GTK_BUTTONS_OK, PChar(mensaje));
  gtk_window_set_title(GTK_WINDOW(dialog), PChar(titulo));
  gtk_dialog_run(GTK_DIALOG(dialog));
  gtk_widget_destroy(dialog);
end;

function ObtenerUsuarioPorEmail(const email: String): String;
var
  actual: PUsuario;
begin
  Result := email; // Por defecto, retornar el email
  if GUsuarios = nil then Exit;
  
  actual := GUsuarios^.cabeza;
  while actual <> nil do
  begin
    if LowerCase(String(actual^.email)) = LowerCase(email) then
    begin
      Result := String(actual^.nombre);
      Exit;
    end;
    actual := actual^.siguiente;
  end;
end;

{ === INTERFAZ CREAR COMUNIDAD (ROOT) === }

var
  EntryNombreComunidad: PGtkWidget = nil;
  TextViewDescripcion: PGtkWidget = nil;
  ComboComunidadesPublicar: PGtkWidget = nil;
  TextViewMensajePublicar: PGtkWidget = nil;
  EntryCorreoPublicar: PGtkWidget = nil;
  ListaMensajesComunidad: PGtkWidget = nil;
  ComunidadSeleccionada: PNodoComunidadBST = nil;

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

procedure CargarComunidadesEnCombo();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  resultado: String;
  comunidades: array of String;
  i, count: Integer;
begin
  if ComboComunidadesPublicar = nil then Exit;
  
  // Limpiar combo
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesPublicar)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Obtener lista de comunidades
  resultado := ObtenerListaComunidades();
  
  if resultado = 'No hay comunidades creadas' then
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar('No hay comunidades creadas'), -1);
  end
  else
  begin
    // Dividir string por |
    SetLength(comunidades, 0);
    count := 0;
    
    // Contar comunidades
    for i := 1 to Length(resultado) do
      if resultado[i] = '|' then Inc(count);
    Inc(count);
    
    SetLength(comunidades, count);
    
    // Extraer nombres
    count := 0;
    i := 1;
    while i <= Length(resultado) do
    begin
      comunidades[count] := '';
      while (i <= Length(resultado)) and (resultado[i] <> '|') do
      begin
        comunidades[count] := comunidades[count] + resultado[i];
        Inc(i);
      end;
      Inc(count);
      Inc(i);
    end;
    
    // Agregar al combo
    for i := 0 to High(comunidades) do
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter, 0, PChar(comunidades[i]), -1);
    end;
  end;
end;

procedure ActualizarListaMensajes();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actualMensaje: PMensajeComunidad;
begin
  if (ComunidadSeleccionada = nil) or (ListaMensajesComunidad = nil) then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaMensajesComunidad)));
  gtk_list_store_clear(store);
  
  actualMensaje := ComunidadSeleccionada^.mensajes;
  while actualMensaje <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(actualMensaje^.fechaPublicacion),
                       1, PChar(actualMensaje^.correo),
                       2, PChar(actualMensaje^.mensaje),
                       -1);
    actualMensaje := actualMensaje^.siguiente;
  end;
end;

procedure OnSeleccionarComunidadParaPublicar(widget: PGtkWidget; data: gpointer); cdecl;
var
  indiceActivo: Integer;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  nombrePtr: PChar;
  nombreCompleto, nombreComunidad: String;
  posParentesis: Integer;
begin
  indiceActivo := gtk_combo_box_get_active(PGtkComboBox(ComboComunidadesPublicar));
  if indiceActivo < 0 then
  begin
    ComunidadSeleccionada := nil;
    Exit;
  end;

  // Obtener nombre de comunidad seleccionada
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesPublicar)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboComunidadesPublicar), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @nombrePtr, -1);
    nombreCompleto := StrPas(nombrePtr);
    g_free(nombrePtr);
    
    // Extraer solo el nombre (antes del paréntesis)
    posParentesis := Pos(' (ID:', nombreCompleto);
    if posParentesis > 0 then
      nombreComunidad := Copy(nombreCompleto, 1, posParentesis - 1)
    else
      nombreComunidad := nombreCompleto;
    
    // Buscar la comunidad en el BST
    ComunidadSeleccionada := BuscarComunidadPorNombre(ArbolComunidades, nombreComunidad);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajes();
    
    WriteLn('🏘️ Comunidad seleccionada para publicar: ', nombreComunidad);
  end;
end;

procedure OnCrearNuevaComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombre, descripcion: String;
  nuevoID: Integer;
begin
  nombre := StrPas(gtk_entry_get_text(PGtkEntry(EntryNombreComunidad)));
  descripcion := ObtenerTextoTextView(TextViewDescripcion);

  // Validaciones
  if (nombre = '') or (descripcion = '') then
  begin
    MostrarMensaje('Error de Validación', 'El nombre y descripción son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Verificar si ya existe
  if BuscarComunidadPorNombre(ArbolComunidades, nombre) <> nil then
  begin
    MostrarMensaje('Error', 'Ya existe una comunidad con ese nombre.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Crear comunidad en BST
  nuevoID := GenerarIDComunidad();
  if InsertarComunidad(ArbolComunidades, nuevoID, nombre, descripcion) then
  begin
    MostrarMensaje('Comunidad Creada', 
      'La comunidad ha sido creada exitosamente en el BST.' + LineEnding + 
      'Nombre: ' + nombre + LineEnding +
      'ID: ' + IntToStr(nuevoID) + LineEnding + LineEnding +
      'Ahora los usuarios pueden publicar mensajes en esta comunidad.', 
      GTK_MESSAGE_INFO);
    
    // Limpiar campos
    gtk_entry_set_text(PGtkEntry(EntryNombreComunidad), '');
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDescripcion)), '', -1);
    
    // Actualizar combo de comunidades
    CargarComunidadesEnCombo();
    
    // Notificar que se creó una comunidad
    if Assigned(OnComunidadCreada) then
      OnComunidadCreada();
  end
  else
    MostrarMensaje('Error', 'No se pudo crear la comunidad en el BST.', GTK_MESSAGE_ERROR);
end;

procedure OnPublicarMensajeRoot(widget: PGtkWidget; data: gpointer); cdecl;
var
  correo, mensaje: String;
begin
  if ComunidadSeleccionada = nil then
  begin
    MostrarMensaje('Error', 'Primero selecciona una comunidad.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  correo := StrPas(gtk_entry_get_text(PGtkEntry(EntryCorreoPublicar)));
  mensaje := ObtenerTextoTextView(TextViewMensajePublicar);
  
  if (correo = '') or (mensaje = '') then
  begin
    MostrarMensaje('Error', 'El correo y mensaje son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Publicar mensaje en la comunidad BST
  if PublicarMensaje(ComunidadSeleccionada, correo, mensaje) then
  begin
    MostrarMensaje('Mensaje Publicado', 
      'El mensaje ha sido publicado exitosamente.' + LineEnding + 
      'Comunidad: ' + ComunidadSeleccionada^.nombre + LineEnding +
      'De: ' + correo, 
      GTK_MESSAGE_INFO);
    
    // Limpiar campos
    gtk_entry_set_text(PGtkEntry(EntryCorreoPublicar), '');
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewMensajePublicar)), '', -1);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajes();
  end
  else
    MostrarMensaje('Error', 'No se pudo publicar el mensaje.', GTK_MESSAGE_ERROR);
end;

procedure OnMostrarRecorridos(widget: PGtkWidget; data: gpointer); cdecl;
begin
  WriteLn('🌳 RECORRIDOS DEL ÁRBOL BST DE COMUNIDADES');
  WriteLn('==========================================');
  WriteLn('📊 Total de comunidades: ', ContarComunidades(ArbolComunidades));
  WriteLn;
  
  WriteLn('🔄 Recorrido In-Orden:');
  InOrdenBST(ArbolComunidades);
  WriteLn;
  
  WriteLn('🔄 Recorrido Pre-Orden:');
  PreOrdenBST(ArbolComunidades);
  WriteLn;
  
  WriteLn('🔄 Recorrido Post-Orden:');
  PostOrdenBST(ArbolComunidades);
  WriteLn('==========================================');
end;

procedure OnCerrarComunidad(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(ComunidadWindow) then
    gtk_widget_destroy(ComunidadWindow);
end;

function OnDeleteEventComunidad(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando gestión comunidades...');
  if Assigned(ComunidadWindow) then
    gtk_widget_destroy(ComunidadWindow);
  Result := True;
end;

procedure MostrarGestionComunidades(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, notebook: PGtkWidget;
  lblTitulo: PGtkWidget;
  
  // Página 1: Crear comunidad
  page1, frame1, hbox1, scrolledDesc1: PGtkWidget;
  lblNombre1, lblDesc1: PGtkWidget;
  btnCrear1: PGtkWidget;
  
  // Página 2: Publicar mensajes
  page2, frame2, hbox2, scrolledMensaje2, scrolledLista2: PGtkWidget;
  lblComunidad2, lblCorreo2, lblMensaje2, lblHistorial2: PGtkWidget;
  btnPublicar2: PGtkWidget;
  
  // Página 3: Ver recorridos
  page3: PGtkWidget;
  btnRecorridos, btnCerrar: PGtkWidget;
  
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  comboStore: PGtkListStore;
begin
  // Guardar referencias globales
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  if Assigned(ComunidadWindow) then
    gtk_widget_destroy(ComunidadWindow);

  ComunidadWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(ComunidadWindow), PChar('🌳 Gestión de Comunidades BST - Root'));
  gtk_window_set_default_size(GTK_WINDOW(ComunidadWindow), 700, 600);
  gtk_window_set_position(GTK_WINDOW(ComunidadWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(ComunidadWindow, 'delete-event', G_CALLBACK(@OnDeleteEventComunidad), nil);

  vbox := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 15);
  gtk_container_add(GTK_CONTAINER(ComunidadWindow), vbox);

  lblTitulo := gtk_label_new(PChar('🌳 Gestión de Comunidades con Árbol BST'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  // Crear notebook con pestañas
  notebook := gtk_notebook_new();
  gtk_box_pack_start(GTK_BOX(vbox), notebook, True, True, 0);

  // === PÁGINA 1: CREAR COMUNIDAD ===
  page1 := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(page1), 20);

  // Frame para crear comunidad
  frame1 := gtk_frame_new('Crear Nueva Comunidad');
  gtk_box_pack_start(GTK_BOX(page1), frame1, False, False, 0);

  hbox1 := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(hbox1), 15);
  gtk_container_add(GTK_CONTAINER(frame1), hbox1);

  // Nombre de comunidad
  lblNombre1 := gtk_label_new('Nombre de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblNombre1), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox1), lblNombre1, False, False, 0);

  EntryNombreComunidad := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox1), EntryNombreComunidad, False, False, 0);

  // Descripción
  lblDesc1 := gtk_label_new('Descripción:');
  gtk_misc_set_alignment(GTK_MISC(lblDesc1), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox1), lblDesc1, False, False, 0);

  scrolledDesc1 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDesc1), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledDesc1, -1, 80);
  gtk_box_pack_start(GTK_BOX(hbox1), scrolledDesc1, False, False, 0);

  TextViewDescripcion := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDescripcion), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDesc1), TextViewDescripcion);

  btnCrear1 := gtk_button_new_with_label('🏘️ Crear Comunidad');
  g_signal_connect(btnCrear1, 'clicked', G_CALLBACK(@OnCrearNuevaComunidad), nil);
  gtk_box_pack_start(GTK_BOX(hbox1), btnCrear1, False, False, 0);

  gtk_notebook_append_page(GTK_NOTEBOOK(notebook), page1, gtk_label_new('Crear Comunidad'));

  // === PÁGINA 2: PUBLICAR MENSAJES ===
  page2 := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(page2), 20);

  // Frame para publicar mensaje
  frame2 := gtk_frame_new('Publicar Mensaje en Comunidad');
  gtk_box_pack_start(GTK_BOX(page2), frame2, False, False, 0);

  hbox2 := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(hbox2), 15);
  gtk_container_add(GTK_CONTAINER(frame2), hbox2);

  // Selector de comunidad
  lblComunidad2 := gtk_label_new('Seleccionar comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblComunidad2), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox2), lblComunidad2, False, False, 0);

  comboStore := gtk_list_store_new(1, G_TYPE_STRING);
  ComboComunidadesPublicar := gtk_combo_box_new_with_model(GTK_TREE_MODEL(comboStore));
  
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboComunidadesPublicar), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboComunidadesPublicar), renderer, 'text', 0, nil);
  
  g_signal_connect(ComboComunidadesPublicar, 'changed', G_CALLBACK(@OnSeleccionarComunidadParaPublicar), nil);
  gtk_box_pack_start(GTK_BOX(hbox2), ComboComunidadesPublicar, False, False, 0);

  // Correo del autor
  lblCorreo2 := gtk_label_new('Correo del autor:');
  gtk_misc_set_alignment(GTK_MISC(lblCorreo2), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox2), lblCorreo2, False, False, 0);

  EntryCorreoPublicar := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(hbox2), EntryCorreoPublicar, False, False, 0);

  // Área de mensaje
  lblMensaje2 := gtk_label_new('Mensaje:');
  gtk_misc_set_alignment(GTK_MISC(lblMensaje2), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox2), lblMensaje2, False, False, 0);

  scrolledMensaje2 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledMensaje2), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledMensaje2, -1, 80);
  gtk_box_pack_start(GTK_BOX(hbox2), scrolledMensaje2, False, False, 0);

  TextViewMensajePublicar := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensajePublicar), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledMensaje2), TextViewMensajePublicar);

  btnPublicar2 := gtk_button_new_with_label('📤 Publicar Mensaje');
  g_signal_connect(btnPublicar2, 'clicked', G_CALLBACK(@OnPublicarMensajeRoot), nil);
  gtk_box_pack_start(GTK_BOX(hbox2), btnPublicar2, False, False, 0);

  // Lista de mensajes de la comunidad seleccionada
  lblHistorial2 := gtk_label_new('Mensajes de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblHistorial2), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page2), lblHistorial2, False, False, 0);

  scrolledLista2 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista2), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(page2), scrolledLista2, True, True, 0);

  store := gtk_list_store_new(3, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaMensajesComunidad := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista2), ListaMensajesComunidad);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesComunidad), column);

  column := gtk_tree_view_column_new_with_attributes('Autor', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesComunidad), column);

  column := gtk_tree_view_column_new_with_attributes('Mensaje', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 300);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesComunidad), column);

  gtk_notebook_append_page(GTK_NOTEBOOK(notebook), page2, gtk_label_new('Publicar Mensajes'));

  // === PÁGINA 3: VER RECORRIDOS ===
  page3 := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(page3), 20);

  btnRecorridos := gtk_button_new_with_label('🌳 Ver Recorridos del BST');
  g_signal_connect(btnRecorridos, 'clicked', G_CALLBACK(@OnMostrarRecorridos), nil);
  gtk_box_pack_start(GTK_BOX(page3), btnRecorridos, False, False, 0);

  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarComunidad), nil);
  gtk_box_pack_start(GTK_BOX(page3), btnCerrar, False, False, 0);

  gtk_notebook_append_page(GTK_NOTEBOOK(notebook), page3, gtk_label_new('Recorridos'));

  // Cargar comunidades en el combo
  CargarComunidadesEnCombo();

  gtk_widget_show_all(ComunidadWindow);
end;

{ === INTERFAZ MIS COMUNIDADES (PARA USUARIOS) === }

var
  ComboComunidadesUsuario: PGtkWidget = nil;
  TextViewMensajeUsuario: PGtkWidget = nil;
  ListaMensajesUsuario: PGtkWidget = nil;
  ComunidadSeleccionadaUsuario: PNodoComunidadBST = nil;
  UsuarioActual: String = '';
  
  // Nuevos controles para crear subcomunidades
  EntryNombreSubcomunidad: PGtkWidget = nil;
  TextViewDescripcionSub: PGtkWidget = nil;
  ComboSeleccionarPadre: PGtkWidget = nil;

procedure ActualizarListaMensajesUsuario();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actualMensaje: PMensajeComunidad;
begin
  if (ComunidadSeleccionadaUsuario = nil) or (ListaMensajesUsuario = nil) then Exit;
  
  store := PGtkListStore(gtk_tree_view_get_model(PGtkTreeView(ListaMensajesUsuario)));
  gtk_list_store_clear(store);
  
  actualMensaje := ComunidadSeleccionadaUsuario^.mensajes;
  while actualMensaje <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(actualMensaje^.fechaPublicacion),
                       1, PChar(actualMensaje^.correo),
                       2, PChar(actualMensaje^.mensaje),
                       -1);
    actualMensaje := actualMensaje^.siguiente;
  end;
end;

procedure OnSeleccionarComunidadUsuario(widget: PGtkWidget; data: gpointer); cdecl;
var
  indiceActivo: Integer;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  nombrePtr: PChar;
  nombreCompleto, nombreComunidad: String;
  posParentesis, posSeparador: Integer;
begin
  indiceActivo := gtk_combo_box_get_active(PGtkComboBox(ComboComunidadesUsuario));
  if indiceActivo < 0 then
  begin
    ComunidadSeleccionadaUsuario := nil;
    Exit;
  end;

  // Obtener nombre de comunidad seleccionada
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesUsuario)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboComunidadesUsuario), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @nombrePtr, -1);
    nombreCompleto := StrPas(nombrePtr);
    g_free(nombrePtr);
    
    // Debug: Mostrar el texto completo
    WriteLn('🔍 Debug - Texto completo del combo: "', nombreCompleto, '"');
    
    // Extraer solo el nombre (antes del paréntesis)
    posParentesis := Pos(' (ID:', nombreCompleto);
    if posParentesis > 0 then
      nombreComunidad := Copy(nombreCompleto, 1, posParentesis - 1)
    else
      nombreComunidad := nombreCompleto;
    
    WriteLn('🔍 Debug - Después de quitar (ID: "', nombreComunidad, '"');
    
    // Si es subcomunidad (contiene " - "), extraer solo el nombre de la subcomunidad
    posSeparador := Pos(' - ', nombreComunidad);
    if posSeparador > 0 then
    begin
      // Es subcomunidad: "netflix - amazon" -> tomar solo "amazon"
      nombreComunidad := Copy(nombreComunidad, posSeparador + 3, Length(nombreComunidad));
      WriteLn('🔍 Debug - Es subcomunidad, nombre extraído: "', nombreComunidad, '"');
    end;
    
    // Limpiar espacios finales
    nombreComunidad := Trim(nombreComunidad);
    WriteLn('🔍 Debug - Nombre final a buscar: "', nombreComunidad, '"');
    
    // Buscar la comunidad en el BST (ahora también buscará subcomunidades)
    ComunidadSeleccionadaUsuario := BuscarComunidadPorNombreCompleto(ArbolComunidades, nombreComunidad);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajesUsuario();
    
    WriteLn('🏘️ Comunidad seleccionada por usuario: ', nombreComunidad);
    if ComunidadSeleccionadaUsuario <> nil then
      WriteLn('✅ Comunidad encontrada, ID: ', ComunidadSeleccionadaUsuario^.id)
    else
      WriteLn('❌ Comunidad no encontrada');
  end;
end;

// Agregar nueva función para buscar en todo el árbol BST
function BuscarComunidadPorNombreCompleto(raiz: PNodoComunidadBST; const nombre: String): PNodoComunidadBST;
begin
  if raiz = nil then
    BuscarComunidadPorNombreCompleto := nil
  else if LowerCase(raiz^.nombre) = LowerCase(nombre) then
    BuscarComunidadPorNombreCompleto := raiz
  else
  begin
    // Buscar en ambos lados ya que las subcomunidades pueden estar en cualquier lado
    BuscarComunidadPorNombreCompleto := BuscarComunidadPorNombreCompleto(raiz^.izquierdo, nombre);
    if BuscarComunidadPorNombreCompleto = nil then
      BuscarComunidadPorNombreCompleto := BuscarComunidadPorNombreCompleto(raiz^.derecho, nombre);
  end;
end;

procedure OnPublicarMensajeUsuario(widget: PGtkWidget; data: gpointer); cdecl;
var
  mensaje: String;
begin
  if ComunidadSeleccionadaUsuario = nil then
  begin
    MostrarMensaje('Error', 'Selecciona una comunidad primero.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  mensaje := ObtenerTextoTextView(TextViewMensajeUsuario);
  
  if mensaje = '' then
  begin
    MostrarMensaje('Error', 'Escribe un mensaje.', GTK_MESSAGE_ERROR);
    Exit;
  end;

  // Publicar mensaje en la comunidad BST
  if PublicarMensaje(ComunidadSeleccionadaUsuario, UsuarioActual, mensaje) then
  begin
    MostrarMensaje('Mensaje Publicado', 
      'Tu mensaje ha sido publicado en la comunidad.' + LineEnding + 
      'Comunidad: ' + ComunidadSeleccionadaUsuario^.nombre, 
      GTK_MESSAGE_INFO);
    
    // Limpiar campo de mensaje
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewMensajeUsuario)), '', -1);
    
    // Actualizar lista de mensajes
    ActualizarListaMensajesUsuario();
  end
  else
    MostrarMensaje('Error', 'No se pudo publicar el mensaje.', GTK_MESSAGE_ERROR);
end;

procedure CargarComunidadesPrincipales();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  resultado: String;
  comunidades: array of String;
  i, count: Integer;
begin
  if ComboSeleccionarPadre = nil then Exit;
  
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboSeleccionarPadre)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Función auxiliar para cargar solo comunidades principales
  resultado := ObtenerListaComunidades(); // Solo comunidades principales del root
  
  if resultado <> 'No hay comunidades creadas' then
  begin
    // Procesar lista de comunidades principales
    SetLength(comunidades, 0);
    count := 0;
    
    for i := 1 to Length(resultado) do
      if resultado[i] = '|' then Inc(count);
    Inc(count);
    
    SetLength(comunidades, count);
    
    count := 0;
    i := 1;
    while i <= Length(resultado) do
    begin
      comunidades[count] := '';
      while (i <= Length(resultado)) and (resultado[i] <> '|') do
      begin
        comunidades[count] := comunidades[count] + resultado[i];
        Inc(i);
      end;
      Inc(count);
      Inc(i);
    end;
    
    for i := 0 to High(comunidades) do
    begin
      gtk_list_store_append(store, @iter);
      if Pos(' (ID:', comunidades[i]) > 0 then
        gtk_list_store_set(store, @iter, 0, PChar(Copy(comunidades[i], 1, Pos(' (ID:', comunidades[i]) - 1)), -1)
      else
        gtk_list_store_set(store, @iter, 0, PChar(comunidades[i]), -1);
    end;
  end;
end;

procedure CargarComunidadesUsuario();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  resultado: String;
  comunidades: array of String;
  i, count: Integer;
  nombreMostrar: String;
  posParentesis: Integer;
begin
  if (ComboComunidadesUsuario = nil) or (UsuarioActual = '') then Exit;
  
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidadesUsuario)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Obtener comunidades que el usuario puede ver (principales + subcomunidades propias)
  resultado := ObtenerComunidadesParaUsuario(UsuarioActual);
  
  if resultado = 'No hay comunidades disponibles' then
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar('No hay comunidades disponibles'), -1);
  end
  else
  begin
    // Procesar lista
    SetLength(comunidades, 0);
    count := 0;
    
    for i := 1 to Length(resultado) do
      if resultado[i] = '|' then Inc(count);
    Inc(count);
    
    SetLength(comunidades, count);
    
    count := 0;
    i := 1;
    while i <= Length(resultado) do
    begin
      comunidades[count] := '';
      while (i <= Length(resultado)) and (resultado[i] <> '|') do
      begin
        comunidades[count] := comunidades[count] + resultado[i];
        Inc(i);
      end;
      Inc(count);
      Inc(i);
    end;
    
    for i := 0 to High(comunidades) do
    begin
      gtk_list_store_append(store, @iter);
      // Mostrar tal como viene (ya formateado con "padre - subcomunidad")
      nombreMostrar := comunidades[i];
      
      // Eliminar (ID: xxx) para mostrar solo en el combo si queremos
      posParentesis := Pos(' (ID:', nombreMostrar);
      if posParentesis > 0 then
        nombreMostrar := Copy(nombreMostrar, 1, posParentesis - 1) + Copy(nombreMostrar, posParentesis, Length(nombreMostrar));
      
      gtk_list_store_set(store, @iter, 0, PChar(nombreMostrar), -1);
    end;
  end;
end;

procedure OnCrearSubcomunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  nombreSub, descripcionSub: String;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  nombrePadrePtr: PChar;
  nombrePadre: String;
  comunidadPadre: PNodoComunidadBST;
  nuevoID: Integer;
begin
  nombreSub := StrPas(gtk_entry_get_text(PGtkEntry(EntryNombreSubcomunidad)));
  descripcionSub := ObtenerTextoTextView(TextViewDescripcionSub);
  
  if (nombreSub = '') or (descripcionSub = '') then
  begin
    MostrarMensaje('Error', 'Nombre y descripción son obligatorios.', GTK_MESSAGE_ERROR);
    Exit;
  end;
  
  // Obtener comunidad padre seleccionada
  if gtk_combo_box_get_active(PGtkComboBox(ComboSeleccionarPadre)) < 0 then
  begin
    MostrarMensaje('Error', 'Selecciona una comunidad principal.', GTK_MESSAGE_ERROR);
    Exit;
  end;
  
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboSeleccionarPadre)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboSeleccionarPadre), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @nombrePadrePtr, -1);
    nombrePadre := StrPas(nombrePadrePtr);
    g_free(nombrePadrePtr);
    
    comunidadPadre := BuscarComunidadPorNombre(ArbolComunidades, nombrePadre);
    if comunidadPadre = nil then
    begin
      MostrarMensaje('Error', 'Comunidad padre no encontrada.', GTK_MESSAGE_ERROR);
      Exit;
    end;
    
    // Verificar que sea una comunidad principal (no subcomunidad)
    if comunidadPadre^.esSubcomunidad then
    begin
      MostrarMensaje('Error', 'No se pueden crear subcomunidades dentro de otras subcomunidades.', GTK_MESSAGE_ERROR);
      Exit;
    end;
    
    // Crear subcomunidad
    nuevoID := GenerarIDComunidad();
    if InsertarSubcomunidad(comunidadPadre, nuevoID, nombreSub, descripcionSub, UsuarioActual) then
    begin
      MostrarMensaje('Subcomunidad Creada', 
        'Subcomunidad creada exitosamente:' + LineEnding + 
        'Nombre: ' + nombreSub + LineEnding +
        'Dentro de: ' + nombrePadre + LineEnding +
        'Creador: ' + UsuarioActual, 
        GTK_MESSAGE_INFO);
      
      // Limpiar campos
      gtk_entry_set_text(PGtkEntry(EntryNombreSubcomunidad), '');
      gtk_text_buffer_set_text(gtk_text_view_get_buffer(PGtkTextView(TextViewDescripcionSub)), '', -1);
      
      // Actualizar listas
      CargarComunidadesUsuario();
    end
    else
      MostrarMensaje('Error', 'No se pudo crear la subcomunidad.', GTK_MESSAGE_ERROR);
  end;
end;

procedure OnCerrarMisComunidades(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(MisComunidadesWindow) then
    gtk_widget_destroy(MisComunidadesWindow);
end;

function OnDeleteEventMisComunidades(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando mis comunidades...');
  if Assigned(MisComunidadesWindow) then
    gtk_widget_destroy(MisComunidadesWindow);
  Result := True;
end;

procedure MostrarMisComunidades(const emailUsuario: String; var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  vbox, notebook: PGtkWidget;
  lblTitulo: PGtkWidget;
  
  // Página 1: Publicar mensajes (existente)
  page1, frame1, hbox1, scrolledMensaje1, scrolledLista1: PGtkWidget;
  lblComunidad1, lblMensaje1, lblHistorial1: PGtkWidget;
  btnPublicar1: PGtkWidget;
  
  // Página 2: Crear subcomunidades (nueva)
  page2, scrolledDesc2: PGtkWidget;
  lblNombreSub, lblDescSub, lblPadre: PGtkWidget;
  btnCrearSub: PGtkWidget;
  
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  comboStore: PGtkListStore;
begin
  // Guardar referencias globales
  UsuarioActual := emailUsuario;
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  if Assigned(MisComunidadesWindow) then
    gtk_widget_destroy(MisComunidadesWindow);

  MisComunidadesWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(MisComunidadesWindow), PChar('🏘️ Mis Comunidades BST - ' + emailUsuario));
  gtk_window_set_default_size(GTK_WINDOW(MisComunidadesWindow), 600, 500);
  gtk_window_set_position(GTK_WINDOW(MisComunidadesWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(MisComunidadesWindow, 'delete-event', G_CALLBACK(@OnDeleteEventMisComunidades), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(MisComunidadesWindow), vbox);

  lblTitulo := gtk_label_new(PChar('🌳 Espacios de Comunidad BST'));
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  // Crear notebook con pestañas
  notebook := gtk_notebook_new();
  gtk_box_pack_start(GTK_BOX(vbox), notebook, True, True, 0);

  // === PÁGINA 1: PUBLICAR MENSAJES ===
  page1 := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(page1), 20);

  // Frame para publicar mensaje
  frame1 := gtk_frame_new('Publicar Mensaje');
  gtk_box_pack_start(GTK_BOX(page1), frame1, False, False, 0);

  hbox1 := gtk_vbox_new(False, 10);
  gtk_container_set_border_width(GTK_CONTAINER(hbox1), 15);
  gtk_container_add(GTK_CONTAINER(frame1), hbox1);

  // Selector de comunidad
  lblComunidad1 := gtk_label_new('Seleccionar comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblComunidad1), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox1), lblComunidad1, False, False, 0);

  comboStore := gtk_list_store_new(1, G_TYPE_STRING);
  ComboComunidadesUsuario := gtk_combo_box_new_with_model(GTK_TREE_MODEL(comboStore));
  
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboComunidadesUsuario), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboComunidadesUsuario), renderer, 'text', 0, nil);
  
  g_signal_connect(ComboComunidadesUsuario, 'changed', G_CALLBACK(@OnSeleccionarComunidadUsuario), nil);
  gtk_box_pack_start(GTK_BOX(hbox1), ComboComunidadesUsuario, False, False, 0);

  // Área de mensaje
  lblMensaje1 := gtk_label_new('Mensaje:');
  gtk_misc_set_alignment(GTK_MISC(lblMensaje1), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(hbox1), lblMensaje1, False, False, 0);

  scrolledMensaje1 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledMensaje1), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledMensaje1, -1, 80);
  gtk_box_pack_start(GTK_BOX(hbox1), scrolledMensaje1, False, False, 0);

  TextViewMensajeUsuario := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewMensajeUsuario), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledMensaje1), TextViewMensajeUsuario);

  btnPublicar1 := gtk_button_new_with_label('📤 Publicar');
  g_signal_connect(btnPublicar1, 'clicked', G_CALLBACK(@OnPublicarMensajeUsuario), nil);
  gtk_box_pack_start(GTK_BOX(hbox1), btnPublicar1, False, False, 0);

  // Lista de mensajes
  lblHistorial1 := gtk_label_new('Mensajes de la comunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblHistorial1), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page1), lblHistorial1, False, False, 0);

  scrolledLista1 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista1), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(page1), scrolledLista1, True, True, 0);

  store := gtk_list_store_new(3, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  ListaMensajesUsuario := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista1), ListaMensajesUsuario);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 120);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesUsuario), column);

  column := gtk_tree_view_column_new_with_attributes('Autor', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesUsuario), column);

  column := gtk_tree_view_column_new_with_attributes('Mensaje', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 300);
  gtk_tree_view_append_column(GTK_TREE_VIEW(ListaMensajesUsuario), column);

  gtk_notebook_append_page(GTK_NOTEBOOK(notebook), page1, gtk_label_new('Participar'));

  // === PÁGINA 2: CREAR SUBCOMUNIDADES ===
  page2 := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(page2), 20);

  lblNombreSub := gtk_label_new('Nombre de la subcomunidad:');
  gtk_misc_set_alignment(GTK_MISC(lblNombreSub), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page2), lblNombreSub, False, False, 0);
  
  EntryNombreSubcomunidad := gtk_entry_new();
  gtk_box_pack_start(GTK_BOX(page2), EntryNombreSubcomunidad, False, False, 0);

  lblPadre := gtk_label_new('Seleccionar comunidad principal:');
  gtk_misc_set_alignment(GTK_MISC(lblPadre), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page2), lblPadre, False, False, 0);

  comboStore := gtk_list_store_new(1, G_TYPE_STRING);
  ComboSeleccionarPadre := gtk_combo_box_new_with_model(GTK_TREE_MODEL(comboStore));
  
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboSeleccionarPadre), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboSeleccionarPadre), renderer, 'text', 0, nil);
  
  gtk_box_pack_start(GTK_BOX(page2), ComboSeleccionarPadre, False, False, 0);

  lblDescSub := gtk_label_new('Descripción:');
  gtk_misc_set_alignment(GTK_MISC(lblDescSub), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(page2), lblDescSub, False, False, 0);

  scrolledDesc2 := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledDesc2), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_widget_set_size_request(scrolledDesc2, -1, 100);
  gtk_box_pack_start(GTK_BOX(page2), scrolledDesc2, False, False, 0);

  TextViewDescripcionSub := gtk_text_view_new();
  gtk_text_view_set_wrap_mode(PGtkTextView(TextViewDescripcionSub), GTK_WRAP_WORD);
  gtk_container_add(GTK_CONTAINER(scrolledDesc2), TextViewDescripcionSub);

  btnCrearSub := gtk_button_new_with_label('🏘️ Crear Subcomunidad');
  g_signal_connect(btnCrearSub, 'clicked', G_CALLBACK(@OnCrearSubcomunidad), nil);
  gtk_box_pack_start(GTK_BOX(page2), btnCrearSub, False, False, 0);

  gtk_notebook_append_page(GTK_NOTEBOOK(notebook), page2, gtk_label_new('Crear Subcomunidad'));

  // Cargar datos iniciales
  CargarComunidadesUsuario();
  CargarComunidadesPrincipales();

  gtk_widget_show_all(MisComunidadesWindow);
end;

initialization
  InicializarComunidades();

finalization
  LiberarArbolBST(ArbolComunidades);

end.
