unit root_menu;

{$mode objfpc}{$H+}

interface

uses
  glib2, gtk2, gdk2, SysUtils,
  listasimple2, cola2, arbol_avl, arbol_b, json_loader, login, comunidad, arbolbst, reports;

// Mostrar el menú root utilizando las mismas estructuras compartidas en toda la app
procedure MostrarMenuRoot(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);

implementation

var
  // Referencias compartidas a las estructuras de datos (no crear copias locales)
  GUsuarios: ^TListaSimple = nil;
  GProgramados: ^TCola = nil;
  GBorradores: ^PCorreoAVL = nil;
  GFavoritos: ^PNodoB = nil;
  ComboComunidades: PGtkWidget = nil; // Combo para mostrar comunidades
  MensajesWindow: PGtkWidget = nil; // Ventana para ver todos los mensajes

{ --- Callbacks --- }

// Declaración forward de la función
procedure MostrarTodosMensajesComunidades(); forward;

function OnDeleteEventMensajes(widget: PGtkWidget; event: PGdkEvent; data: gpointer): gboolean; cdecl;
begin
  WriteLn('🔓 Cerrando vista de mensajes...');
  if Assigned(MensajesWindow) then
    gtk_widget_destroy(MensajesWindow);
  Result := True;
end;

procedure OnCerrarMensajes(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if Assigned(MensajesWindow) then
    gtk_widget_destroy(MensajesWindow);
end;

// Callback para recolectar información de comunidades
procedure CallbackActualizarCombo(comunidad: PNodoComunidadBST; data: Pointer);
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  textoComunidad: String;
begin
  if (comunidad <> nil) and (data <> nil) then
  begin
    store := PGtkListStore(data);
    textoComunidad := comunidad^.nombre + ' (ID: ' + IntToStr(comunidad^.id) + ') - ' + IntToStr(comunidad^.totalMensajes) + ' mensajes';
    
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar(textoComunidad), -1);
  end;
end;

procedure ActualizarComboComunidades();
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  totalComunidades: Integer;
begin
  if ComboComunidades = nil then Exit;
  
  // Limpiar combo
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidades)));
  if store <> nil then
    gtk_list_store_clear(store);
  
  // Contar comunidades primero
  totalComunidades := ContarComunidades(ArbolComunidades);
  
  if totalComunidades = 0 then
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter, 0, PChar('No hay comunidades creadas'), -1);
  end
  else
  begin
    // Usar recorrido personalizado para llenar combo
    RecorridoPersonalizadoBST(ArbolComunidades, @CallbackActualizarCombo, store);
  end;
end;

procedure OnActualizarCombo(); // Callback para cuando se crea una comunidad
begin
  ActualizarComboComunidades();
  WriteLn('🔄 Combo de comunidades actualizado');
end;

procedure OnCargaMasiva(widget: PGtkWidget; data: gpointer); cdecl;
begin
  if (GUsuarios = nil) or (GProgramados = nil) or (GBorradores = nil) or (GFavoritos = nil) then
  begin
    g_print('>> ❌ Error: estructuras no inicializadas en root_menu' + LineEnding);
    Exit;
  end;

  // Reiniciar estructuras y cargar desde JSON
  InicializarLista(GUsuarios^);
  InicializarCola(GProgramados^);
  arbol_avl.Inicializar(GBorradores^);
  arbol_b.Inicializar(GFavoritos^);

  // Carga masiva unificada (permite recargar si se desea)
  CargaMasivaDesdeJSON('/home/angel/Desktop/EDD_FASE1_202304063/Fase2/datos/usuarios.json', '/home/angel/Desktop/EDD_FASE1_202304063/Fase2/datos/correos.json',
                       GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);

  g_print('>> ✅ Carga masiva completada.' + LineEnding);

  gtk_message_dialog_new(nil,
    GTK_DIALOG_MODAL,
    GTK_MESSAGE_INFO,
    GTK_BUTTONS_OK,
    'Carga masiva completada correctamente.');
end;

procedure OnCrearComunidad(widget: PGtkWidget; data: gpointer); cdecl;
begin
  // Establecer callback para actualizar combo cuando se cree comunidad
  OnComunidadCreada := @OnActualizarCombo;
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
    MostrarGestionComunidades(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnReporteComunidades(widget: PGtkWidget; data: gpointer); cdecl;
var
  rutaDir, rutaDot, rutaPng: String;
begin
  // Mostrar reporte en consola
  WriteLn('🌳 REPORTE DE COMUNIDADES BST');
  WriteLn('=============================');
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
  WriteLn('=============================');
  
  // Generar reporte gráfico en carpeta root
  rutaDir := ExtractFileDir(ExtractFileDir(ParamStr(0))) + '/graficos/root';
  if not DirectoryExists(rutaDir) then
    CreateDir(rutaDir);
  
  rutaDot := rutaDir + '/bst-comunidades.dot';
  rutaPng := rutaDir + '/bst-comunidades.png';
  
  // Generar DOT del BST
  GenerarReporteBSTComunidades(rutaDot);
  
  // Intentar generar PNG
  if ExecuteProcess('/bin/sh', ['-c', 'command -v dot >/dev/null 2>&1'], []) = 0 then
  begin
    if ExecuteProcess('/bin/sh', ['-c', 'dot -Tpng "' + rutaDot + '" -o "' + rutaPng + '"'], []) = 0 then
    begin
      WriteLn('🖼️ Gráfico BST generado: ', rutaPng);
      
      // Mostrar diálogo informativo
      gtk_message_dialog_new(nil,
        GTK_DIALOG_MODAL,
        GTK_MESSAGE_INFO,
        GTK_BUTTONS_OK,
        PChar('🌳 Reporte BST generado exitosamente!' + #10 + #10 +
              'Archivos generados:' + #10 +
              '📄 DOT: ' + ExtractFileName(rutaDot) + #10 +
              '🖼️ PNG: ' + ExtractFileName(rutaPng) + #10 + #10 +
              'Ubicación: /graficos/root/'));
    end
    else
    begin
      WriteLn('⚠️ Error generando PNG del BST');
      gtk_message_dialog_new(nil,
        GTK_DIALOG_MODAL,
        GTK_MESSAGE_WARNING,
        GTK_BUTTONS_OK,
        'Archivo DOT generado, pero no se pudo crear el PNG.');
    end;
  end
  else
  begin
    WriteLn('ℹ️ Graphviz no instalado, solo DOT generado');
    gtk_message_dialog_new(nil,
      GTK_DIALOG_MODAL,
      GTK_MESSAGE_INFO,
      GTK_BUTTONS_OK,
      PChar('Archivo DOT generado: ' + ExtractFileName(rutaDot) + #10 +
            'Instala Graphviz para generar imágenes PNG.'));
  end;
end;

procedure OnVerMensajes(widget: PGtkWidget; data: gpointer); cdecl;
begin
  MostrarTodosMensajesComunidades();
end;

procedure OnSalir(widget: PGtkWidget; data: gpointer); cdecl;
begin
  // Cerrar ventana actual y regresar al login
  if Assigned(widget) then
    gtk_widget_destroy(gtk_widget_get_toplevel(widget));
  
  // Reabrir login para que usuarios normales puedan autenticarse
  if (GUsuarios <> nil) and (GProgramados <> nil) and (GBorradores <> nil) and (GFavoritos <> nil) then
    MostrarLogin(GUsuarios^, GProgramados^, GBorradores^, GFavoritos^);
end;

procedure OnSeleccionarComunidad(widget: PGtkWidget; data: gpointer); cdecl;
var
  indiceActivo: Integer;
  store: PGtkListStore;
  iter: TGtkTreeIter;
  textoComunidadPtr: PChar;
  textoComunidad: String;
begin
  indiceActivo := gtk_combo_box_get_active(PGtkComboBox(ComboComunidades));
  if indiceActivo < 0 then
  begin
    g_print(PChar('No hay comunidad seleccionada' + LineEnding));
    Exit;
  end;

  // Obtener texto de comunidad seleccionada
  store := PGtkListStore(gtk_combo_box_get_model(PGtkComboBox(ComboComunidades)));
  if gtk_combo_box_get_active_iter(PGtkComboBox(ComboComunidades), @iter) then
  begin
    gtk_tree_model_get(GTK_TREE_MODEL(store), @iter, 0, @textoComunidadPtr, -1);
    textoComunidad := StrPas(textoComunidadPtr);
    g_free(textoComunidadPtr);
    
    g_print(PChar('📋 Comunidad seleccionada: ' + textoComunidad + LineEnding));
  end;
end;

// Callback para recolectar mensajes del BST
procedure CallbackRecolectarMensajes(comunidad: PNodoComunidadBST; data: Pointer);
var
  store: PGtkListStore;
  iter: TGtkTreeIter;
  actualMensaje: PMensajeComunidad;
  nombreComunidadCompleto: String;
begin
  if (comunidad = nil) or (data = nil) then Exit;
  
  store := PGtkListStore(data);
  actualMensaje := comunidad^.mensajes;
  
  // Construir nombre completo con jerarquía
  if comunidad^.esSubcomunidad and (comunidad^.comunidadPadre <> nil) then
    nombreComunidadCompleto := comunidad^.comunidadPadre^.nombre + ' - ' + comunidad^.nombre
  else
    nombreComunidadCompleto := comunidad^.nombre;
  
  while actualMensaje <> nil do
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar(nombreComunidadCompleto),
                       1, PChar(IntToStr(actualMensaje^.id)),
                       2, PChar(actualMensaje^.fechaPublicacion),
                       3, PChar(actualMensaje^.correo),
                       4, PChar(actualMensaje^.mensaje),
                       -1);
    actualMensaje := actualMensaje^.siguiente;
  end;
end;

procedure MostrarTodosMensajesComunidades();
var
  vbox, scrolledLista, btnBox: PGtkWidget;
  lblTitulo, lblInfo: PGtkWidget;
  treeView: PGtkWidget;
  store: PGtkListStore;
  column: PGtkTreeViewColumn;
  renderer: PGtkCellRenderer;
  iter: TGtkTreeIter;
  btnCerrar: PGtkWidget;
  totalMensajes, totalComunidades: Integer;
begin
  if Assigned(MensajesWindow) then
    gtk_widget_destroy(MensajesWindow);

  MensajesWindow := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(MensajesWindow), PChar('💬 Todos los Mensajes de Comunidades BST - Root'));
  gtk_window_set_default_size(GTK_WINDOW(MensajesWindow), 900, 600);
  gtk_window_set_position(GTK_WINDOW(MensajesWindow), GTK_WIN_POS_CENTER);

  g_signal_connect(MensajesWindow, 'delete-event', G_CALLBACK(@OnDeleteEventMensajes), nil);

  vbox := gtk_vbox_new(False, 15);
  gtk_container_set_border_width(GTK_CONTAINER(vbox), 20);
  gtk_container_add(GTK_CONTAINER(MensajesWindow), vbox);

  lblTitulo := gtk_label_new('💬 Vista Global de Mensajes del Árbol BST');
  gtk_box_pack_start(GTK_BOX(vbox), lblTitulo, False, False, 0);

  // Contar totales
  totalComunidades := ContarComunidades(ArbolComunidades);
  totalMensajes := 0; // Se contará durante el llenado

  lblInfo := gtk_label_new(PChar('Total: ' + IntToStr(totalComunidades) + ' comunidades en el BST'));
  gtk_box_pack_start(GTK_BOX(vbox), lblInfo, False, False, 0);

  // Lista de mensajes
  scrolledLista := gtk_scrolled_window_new(nil, nil);
  gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scrolledLista), 
                                 GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);
  gtk_box_pack_start(GTK_BOX(vbox), scrolledLista, True, True, 0);

  // Crear modelo y vista
  store := gtk_list_store_new(5, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeView := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));
  gtk_container_add(GTK_CONTAINER(scrolledLista), treeView);

  // Columnas
  renderer := gtk_cell_renderer_text_new();
  
  column := gtk_tree_view_column_new_with_attributes('Comunidad', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_column_set_resizable(column, True);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('ID Msg', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 70);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 130);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Autor', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 180);
  gtk_tree_view_column_set_resizable(column, True);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  column := gtk_tree_view_column_new_with_attributes('Mensaje', renderer, 'text', 4, nil);
  gtk_tree_view_column_set_min_width(column, 300);
  gtk_tree_view_column_set_resizable(column, True);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeView), column);

  // Cargar todos los mensajes usando recorrido personalizado del BST
  if ArbolComunidades <> nil then
    RecorridoPersonalizadoBST(ArbolComunidades, @CallbackRecolectarMensajes, store);

  // Si no hay mensajes, mostrar mensaje informativo
  if totalComunidades = 0 then
  begin
    gtk_list_store_append(store, @iter);
    gtk_list_store_set(store, @iter,
                       0, PChar('--- Sin comunidades ---'),
                       1, PChar('--'),
                       2, PChar('--'),
                       3, PChar('--'),
                       4, PChar('No hay comunidades creadas en el BST'),
                       -1);
  end;

  // Botón cerrar
  btnBox := gtk_hbox_new(False, 0);
  gtk_box_pack_start(GTK_BOX(vbox), btnBox, False, False, 0);

  btnCerrar := gtk_button_new_with_label('❌ Cerrar');
  g_signal_connect(btnCerrar, 'clicked', G_CALLBACK(@OnCerrarMensajes), nil);
  gtk_box_pack_start(GTK_BOX(btnBox), btnCerrar, False, False, 0);

  WriteLn('💬 Mostrando mensajes de ', totalComunidades, ' comunidades del BST');
  gtk_widget_show_all(MensajesWindow);
end;

{ --- Ventana principal --- }

procedure MostrarMenuRoot(var usuarios: TListaSimple; var programados: TCola; var borradores: PCorreoAVL; var favoritos: PNodoB);
var
  window: PGtkWidget;
  vbox, hboxCombo: PGtkWidget;
  btnCarga, btnComunidad, btnReporte, btnMensajes, btnSalir: PGtkWidget;
  lblComunidades: PGtkWidget;
  store: PGtkListStore;
  renderer: PGtkCellRenderer;
begin
  // Guardar referencias a las estructuras compartidas
  GUsuarios := @usuarios;
  GProgramados := @programados;
  GBorradores := @borradores;
  GFavoritos := @favoritos;

  { Ventana }
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Menú Root - EDDMail BST');
  gtk_window_set_default_size(GTK_WINDOW(window), 500, 400);
  gtk_container_set_border_width(GTK_CONTAINER(window), 20);

  g_signal_connect(window, 'destroy', G_CALLBACK(@OnSalir), nil);

  { Caja vertical }
  vbox := gtk_vbox_new(False, 15);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  { Botones principales }
  btnCarga := gtk_button_new_with_label('1. Carga masiva JSON');
  g_signal_connect(btnCarga, 'clicked', G_CALLBACK(@OnCargaMasiva), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnCarga, False, False, 0);

  btnComunidad := gtk_button_new_with_label('2. 🌳 Crear comunidad BST');
  g_signal_connect(btnComunidad, 'clicked', G_CALLBACK(@OnCrearComunidad), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnComunidad, False, False, 0);

  { Sección de comunidades existentes }
  lblComunidades := gtk_label_new('📋 Comunidades Existentes (BST):');
  gtk_misc_set_alignment(GTK_MISC(lblComunidades), 0.0, 0.5);
  gtk_box_pack_start(GTK_BOX(vbox), lblComunidades, False, False, 5);

  hboxCombo := gtk_hbox_new(False, 10);
  gtk_box_pack_start(GTK_BOX(vbox), hboxCombo, False, False, 0);

  // Crear combo para comunidades
  store := gtk_list_store_new(1, G_TYPE_STRING);
  ComboComunidades := gtk_combo_box_new_with_model(GTK_TREE_MODEL(store));
  
  renderer := gtk_cell_renderer_text_new();
  gtk_cell_layout_pack_start(GTK_CELL_LAYOUT(ComboComunidades), renderer, True);
  gtk_cell_layout_set_attributes(GTK_CELL_LAYOUT(ComboComunidades), renderer, 'text', 0, nil);
  
  g_signal_connect(ComboComunidades, 'changed', G_CALLBACK(@OnSeleccionarComunidad), nil);
  gtk_box_pack_start(GTK_BOX(hboxCombo), ComboComunidades, True, True, 0);

  { Botones restantes }
  btnReporte := gtk_button_new_with_label('3. 🌳 Reporte BST comunidades');
  g_signal_connect(btnReporte, 'clicked', G_CALLBACK(@OnReporteComunidades), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnReporte, False, False, 0);

  btnMensajes := gtk_button_new_with_label('4. 💬 Ver mensajes BST');
  g_signal_connect(btnMensajes, 'clicked', G_CALLBACK(@OnVerMensajes), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnMensajes, False, False, 0);

  btnSalir := gtk_button_new_with_label('Salir');
  g_signal_connect(btnSalir, 'clicked', G_CALLBACK(@OnSalir), nil);
  gtk_box_pack_start(GTK_BOX(vbox), btnSalir, False, False, 0);

  // Cargar comunidades iniciales en el combo
  ActualizarComboComunidades();

  gtk_widget_show_all(window);
end;

end.
