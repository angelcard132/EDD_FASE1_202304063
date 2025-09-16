{
  INTERFAZ GRÁFICA: BANDEJA DE ENTRADA
  
  Este módulo implementa la bandeja de entrada de correos para usuarios.
  Permite visualizar, leer, eliminar y ordenar correos recibidos.
  
  Funcionalidades principales:
  - Mostrar correos recibidos del usuario activo
  - Ordenamiento dinámico por asunto (A-Z, Z-A) y fecha
  - Ver detalles completos de correos
  - Mover correos a papelera (estructura LIFO)
  - Cambio automático de estado a "Leído" al abrir
}
unit bandeja;

{$mode objfpc}{$H+}

interface

uses
  glib2,           // Funciones base de GTK
  gtk2,            // Interfaz gráfica GTK2
  lista_doble,     // Lista doblemente enlazada para correos
  lista_simple,    // Para verificar usuarios válidos
  json_loader,     // Carga de datos JSON
  SysUtils,        // Funciones del sistema
  StrUtils,        // Utilidades de strings
  papelera,        // Manejo de papelera
  globals,         // Variables globales
  redactar,        // Para redactar respuestas
  pila;            // Estructura LIFO para papelera

// Procedimiento principal para mostrar la bandeja del usuario
procedure MostrarBandeja(const usuario: TUsuario);

implementation

{
  LIMPIAR UTF8
  
  Función utilitaria para limpiar caracteres problemáticos en textos.
  Reemplaza caracteres no ASCII con signos de interrogación.
  Previene errores de codificación en la interfaz GTK.
}
function LimpiarUTF8(const texto: String): String;
var
  i: Integer;
  resultado: String;
begin
  resultado := '';
  for i := 1 to Length(texto) do
  begin
    if Ord(texto[i]) < 128 then  // Solo caracteres ASCII seguros
      resultado := resultado + texto[i]
    else
      resultado := resultado + '?';  // Reemplazar caracteres problemáticos
  end;
  Result := resultado;
end;

{
  MOSTRAR DETALLE DE CORREO
  
  Abre una ventana modal con los detalles completos de un correo.
  Automáticamente cambia el estado del correo de 'NL' (No Leído) a 'L' (Leído).
  
  Parámetros:
  - correo: Puntero al correo a mostrar
}
procedure MostrarDetalleCorreo(correo: PCorreo);
var
  window, vbox, labelInfo, textView, scroll: PGtkWidget;
  buffer: PGtkTextBuffer;
  detalle: String;
begin
  // Cambiar estado a leído automáticamente al abrir el detalle
  if (correo <> nil) and (correo^.estado <> 'DEL') then
    correo^.estado := 'L';
    
  // === CREAR VENTANA MODAL ===
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), 'Detalle del Correo');
  gtk_window_set_default_size(GTK_WINDOW(window), 450, 350);
  gtk_window_set_modal(GTK_WINDOW(window), TRUE);  // Ventana modal

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // === INFORMACIÓN DEL CORREO ===
  // Construir cadena con información básica del correo
  detalle :=
    'De: ' + LimpiarUTF8(correo^.remitente) + LineEnding +
    'Para: ' + LimpiarUTF8(correo^.destinatario) + LineEnding +
    'Asunto: ' + LimpiarUTF8(correo^.asunto) + LineEnding +
    'Fecha: ' + LimpiarUTF8(correo^.fecha);

  labelInfo := gtk_label_new(PChar(detalle));
  gtk_label_set_selectable(GTK_LABEL(labelInfo), True);  // Permitir selección de texto
  gtk_box_pack_start(GTK_BOX(vbox), labelInfo, FALSE, FALSE, 5);

  // === CONTENIDO DEL CORREO ===
  // Área de texto con scroll para el contenido del mensaje
  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 5);

  textView := gtk_text_view_new;
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(textView), GTK_WRAP_WORD);  // Ajuste de línea
  gtk_text_view_set_editable(GTK_TEXT_VIEW(textView), FALSE);           // Solo lectura
  buffer := gtk_text_view_get_buffer(GTK_TEXT_VIEW(textView));
  
  // Verificar que el contenido sea válido UTF-8
  if correo^.contenido <> '' then
    gtk_text_buffer_set_text(buffer, PChar(LimpiarUTF8(correo^.contenido)), -1)
  else
    gtk_text_buffer_set_text(buffer, PChar('(Sin contenido)'), -1);
    
  gtk_container_add(GTK_CONTAINER(scroll), textView);

  gtk_widget_show_all(window);
end;

{
  CALLBACK: ACTIVACIÓN DE FILA
  
  Se ejecuta cuando el usuario hace doble clic en una fila de la tabla.
  Busca el correo correspondiente y abre su detalle.
  
  Manejo de memoria: Libera correctamente los punteros de glib.
}
procedure OnRowActivated(treeview: PGtkTreeView; path: PGtkTreePath; column: PGtkTreeViewColumn; user_data: gpointer); cdecl;
var
  model: PGtkTreeModel;
  iter: TGtkTreeIter;
  pRem: Pgchar = nil;      // Puntero a remitente desde GTK
  pAsu: Pgchar = nil;      // Puntero a asunto desde GTK
  pFec: Pgchar = nil;      // Puntero a fecha desde GTK
  sRem, sAsu, sFec: String;  // Strings convertidos
  aux: PCorreo;              // Puntero auxiliar para búsqueda
begin
  model := gtk_tree_view_get_model(treeview);
  if gtk_tree_model_get_iter(model, @iter, path) then
  begin
    // Obtener strings de la fila (glib asigna memoria que debemos liberar)
    gtk_tree_model_get(model, @iter, 0, @pRem, 1, @pAsu, 2, @pFec, -1);
    
    try
      // Convertir punteros a strings de Pascal con limpieza UTF8
      if pRem <> nil then sRem := LimpiarUTF8(StrPas(pRem));
      if pAsu <> nil then sAsu := LimpiarUTF8(StrPas(pAsu));
      if pFec <> nil then sFec := LimpiarUTF8(StrPas(pFec));

      // Buscar el correo en la lista global usando datos exactos
      aux := CorreosGlobal.primero;
      while aux <> nil do
      begin
        if (LimpiarUTF8(aux^.remitente) = sRem) and 
           (LimpiarUTF8(aux^.asunto) = sAsu) and 
           (LimpiarUTF8(aux^.fecha) = sFec) then
        begin
          MostrarDetalleCorreo(aux);
          // Actualizar estado en la tabla después de leer
          gtk_list_store_set(PGtkListStore(model), @iter, 3, PChar(LimpiarUTF8(aux^.estado)), -1);
          Break;
        end;
        aux := aux^.siguiente;
      end;
    finally
      // IMPORTANTE: Liberar memoria de glib para evitar memory leaks
      if pRem <> nil then g_free(pRem);
      if pAsu <> nil then g_free(pAsu);
      if pFec <> nil then g_free(pFec);
    end;
  end;
end;

{
  FUNCIÓN PRINCIPAL: MOSTRAR BANDEJA
  
  Construye y muestra la interfaz completa de la bandeja de entrada.
  Incluye sistema de ordenamiento dinámico y funcionalidad de eliminación.
}
procedure MostrarBandeja(const usuario: TUsuario);
var
  // Widgets principales de la interfaz
  window, vbox, hboxBotones, hboxOrden, scroll, treeview, btnEliminar: PGtkWidget;
  lblOrden, btnOrdenAZ, btnOrdenZA, btnOrdenFechaAsc, btnOrdenFechaDesc: PGtkWidget;
  store: PGtkListStore;          // Modelo de datos para la tabla
  column: PGtkTreeViewColumn;    // Columnas de la tabla
  renderer: PGtkCellRenderer;    // Renderizador de celdas
  iter: TGtkTreeIter;           // Iterador para agregar filas
  aux: PCorreo;                 // Puntero auxiliar
  correosEncontrados: Integer;  // Contador de correos del usuario
  
  {
    ACTUALIZAR TABLA ORDENADA
    
    Función interna que reordena y actualiza la tabla de correos.
    Utiliza algoritmo de ordenamiento burbuja para simplicidad.
    
    Parámetros:
    - ordenarPor: Criterio de ordenamiento ('asunto', 'remitente', 'fecha')
    - ascendente: True para A-Z, False para Z-A
    
    Complejidad: O(n²) por burbuja + O(n) para llenar tabla
  }
  procedure ActualizarTablaOrdenada(ordenarPor: String; ascendente: Boolean);
  var
    listaCorreos: array of PCorreo;  // Array dinámico para ordenamiento
    i, j, totalCorreos: Integer;     // Contadores de iteración
    temp: PCorreo;                   // Variable temporal para intercambio
    intercambio: Boolean;            // Flag para optimización de burbuja
    comparacion: Integer;            // Resultado de comparación
  begin
    // === LIMPIAR TABLA ACTUAL ===
    gtk_list_store_clear(store);
    
    // === RECOPILAR CORREOS DEL USUARIO ===
    // Filtrar solo correos dirigidos al usuario y no eliminados
    SetLength(listaCorreos, 0);
    aux := CorreosGlobal.primero;
    while aux <> nil do
    begin
      if (LowerCase(aux^.destinatario) = LowerCase(usuario.email)) and (aux^.estado <> 'DEL') then
      begin
        SetLength(listaCorreos, Length(listaCorreos) + 1);
        listaCorreos[High(listaCorreos)] := aux;
      end;
      aux := aux^.siguiente;
    end;
    
    totalCorreos := Length(listaCorreos);
    if totalCorreos = 0 then Exit;  // No hay correos para ordenar
    
    // === ALGORITMO DE ORDENAMIENTO BURBUJA ===
    // Elegido por simplicidad, O(n²) pero suficiente para correos personales
    for i := 0 to totalCorreos - 2 do
    begin
      intercambio := False;
      for j := 0 to totalCorreos - i - 2 do
      begin
        // Determinar comparación según el criterio seleccionado
        if ordenarPor = 'asunto' then
          comparacion := CompareText(listaCorreos[j]^.asunto, listaCorreos[j + 1]^.asunto)
        else if ordenarPor = 'remitente' then
          comparacion := CompareText(listaCorreos[j]^.remitente, listaCorreos[j + 1]^.remitente)
        else if ordenarPor = 'fecha' then
          comparacion := CompareText(listaCorreos[j]^.fecha, listaCorreos[j + 1]^.fecha)
        else
          comparacion := 0;
        
        // Aplicar dirección de ordenamiento (ascendente/descendente)
        if not ascendente then
          comparacion := -comparacion;
        
        // Intercambiar si es necesario
        if comparacion > 0 then
        begin
          temp := listaCorreos[j];
          listaCorreos[j] := listaCorreos[j + 1];
          listaCorreos[j + 1] := temp;
          intercambio := True;
        end;
      end;
      if not intercambio then Break; // Optimización: ya está ordenado
    end;
    
    // === LLENAR TABLA CON DATOS ORDENADOS ===
    for i := 0 to totalCorreos - 1 do
    begin
      gtk_list_store_append(store, @iter);
      gtk_list_store_set(store, @iter,
        0, PChar(LimpiarUTF8(listaCorreos[i]^.remitente)),   // Columna 0
        1, PChar(LimpiarUTF8(listaCorreos[i]^.asunto)),      // Columna 1
        2, PChar(LimpiarUTF8(listaCorreos[i]^.fecha)),       // Columna 2
        3, PChar(LimpiarUTF8(listaCorreos[i]^.estado)),      // Columna 3
        -1);
    end;
    
    // Mostrar resultado del ordenamiento
    if ascendente then
      WriteLn('📧 Correos ordenados por ', ordenarPor, ' (A-Z): ', totalCorreos, ' correos')
    else
      WriteLn('📧 Correos ordenados por ', ordenarPor, ' (Z-A): ', totalCorreos, ' correos');
  end;
  
  // === CALLBACKS PARA BOTONES DE ORDENAMIENTO ===
  
  procedure OnOrdenAZClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('🔤 Ordenando por asunto A-Z...');
    ActualizarTablaOrdenada('asunto', True);
  end;
  
  procedure OnOrdenZAClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('🔤 Ordenando por asunto Z-A...');
    ActualizarTablaOrdenada('asunto', False);
  end;
  
  procedure OnOrdenFechaAscClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('📅 Ordenando por fecha (más antiguos primero)...');
    ActualizarTablaOrdenada('fecha', True);
  end;
  
  procedure OnOrdenFechaDescClicked(widget: PGtkWidget; data: gpointer); cdecl;
  begin
    WriteLn('📅 Ordenando por fecha (más recientes primero)...');
    ActualizarTablaOrdenada('fecha', False);
  end;
  
  {
    CARGAR CORREOS INICIALES
    
    Carga los correos del usuario sin ordenamiento (orden de llegada).
    Filtran solo correos dirigidos al usuario activo y no eliminados.
  }
  procedure CargarCorreosIniciales;
  begin
    // Cargar correos sin ordenamiento (orden original de la lista)
    aux := CorreosGlobal.primero;
    correosEncontrados := 0;
    while aux <> nil do
    begin
      // Filtrar: destinatario = usuario actual AND estado ≠ eliminado
      if (LowerCase(aux^.destinatario) = LowerCase(usuario.email)) and (aux^.estado <> 'DEL') then
      begin
        gtk_list_store_append(store, @iter);
        gtk_list_store_set(store, @iter,
          0, PChar(LimpiarUTF8(aux^.remitente)),
          1, PChar(LimpiarUTF8(aux^.asunto)),
          2, PChar(LimpiarUTF8(aux^.fecha)),
          3, PChar(LimpiarUTF8(aux^.estado)),
          -1);
        Inc(correosEncontrados);
      end;
      aux := aux^.siguiente;
    end;
    WriteLn('📧 Correos en bandeja para ', usuario.email, ': ', correosEncontrados);
  end;

  {
    CALLBACK: ELIMINAR CORREO
    
    Mueve el correo seleccionado a la papelera (estructura LIFO).
    Busca el correo por datos exactos y lo transfiere a la pila.
    
    Proceso:
    1. Obtener datos de la fila seleccionada
    2. Buscar correo en lista global
    3. Agregar a pila de papelera (Push)
    4. Remover de lista global
    5. Actualizar interfaz
  }
  procedure OnEliminarClicked(widget: PGtkWidget; data: gpointer); cdecl;
  var
    selection: PGtkTreeSelection;
    model: PGtkTreeModel;
    iter: TGtkTreeIter;
    pRem, pAsu, pFec: Pgchar;        // Punteros GTK
    sRem, sAsu, sFec: String;        // Strings convertidos
    aux, anterior: PCorreo;          // Punteros para navegación
    encontrado: Boolean;
  begin
    selection := gtk_tree_view_get_selection(GTK_TREE_VIEW(data));
    if not gtk_tree_selection_get_selected(selection, @model, @iter) then
    begin
      WriteLn('⚠️ Selecciona un correo para mover a papelera');
      Exit;
    end;

    // === OBTENER DATOS DE LA FILA SELECCIONADA ===
    pRem := nil; pAsu := nil; pFec := nil;
    try
      gtk_tree_model_get(model, @iter, 0, @pRem, 1, @pAsu, 2, @pFec, -1);
      
      // Validar que se obtuvieron los datos correctamente
      if (pRem = nil) or (pAsu = nil) or (pFec = nil) then
      begin
        WriteLn('❌ Error obteniendo datos del correo seleccionado');
        Exit;
      end;
      
      // Convertir a strings de Pascal
      sRem := StrPas(pRem);
      sAsu := StrPas(pAsu);
      sFec := StrPas(pFec);
      
      WriteLn('🔍 Buscando correo: ', sRem, ' -> ', sAsu, ' (', sFec, ')');
      
      // === BUSCAR CORREO EN LISTA GLOBAL ===
      aux := CorreosGlobal.primero;
      anterior := nil;
      encontrado := False;
      
      while aux <> nil do
      begin
        // Comparar datos exactos: remitente, asunto, fecha y que sea para este usuario
        if (LimpiarUTF8(aux^.remitente) = sRem) and 
           (LimpiarUTF8(aux^.asunto) = sAsu) and 
           (LimpiarUTF8(aux^.fecha) = sFec) and
           (LowerCase(aux^.destinatario) = LowerCase(usuario.email)) and
           (aux^.estado <> 'DEL') then
        begin
          encontrado := True;
          Break;
        end;
        anterior := aux;
        aux := aux^.siguiente;
      end;
      
      if not encontrado or (aux = nil) then
      begin
        WriteLn('❌ No se encontró el correo en la lista global');
        Exit;
      end;
      
      WriteLn('✅ Correo encontrado: ID ', aux^.id, ' - ', aux^.asunto);
      
      // === MOVER A PAPELERA (ESTRUCTURA PILA LIFO) ===
      // Agregar al tope de la pila de papelera del usuario activo
      Push(PapeleraUsuarioActivo, aux^.id, aux^.remitente, aux^.asunto, aux^.fecha, aux^.contenido);
      WriteLn('📧 Correo agregado a papelera: ', aux^.asunto);
      
      // === REMOVER DE LISTA GLOBAL ===
      // Manejo seguro de punteros para evitar corrupción de memoria
      if anterior = nil then
      begin
        // Es el primer elemento de la lista
        CorreosGlobal.primero := aux^.siguiente;
        if CorreosGlobal.ultimo = aux then
          CorreosGlobal.ultimo := nil;
      end
      else
      begin
        // No es el primer elemento
        anterior^.siguiente := aux^.siguiente;
        if CorreosGlobal.ultimo = aux then
          CorreosGlobal.ultimo := anterior;
      end;
      
      // Liberar memoria del nodo original
      Dispose(aux);
      
      // === ACTUALIZAR INTERFAZ ===
      // Remover fila de la tabla GTK
      gtk_list_store_remove(PGtkListStore(model), @iter);
      
      WriteLn('✅ Correo movido a papelera exitosamente');
      
    finally
      // IMPORTANTE: Liberar memoria de glib para evitar memory leaks
      if pRem <> nil then g_free(pRem);
      if pAsu <> nil then g_free(pAsu);
      if pFec <> nil then g_free(pFec);
    end;
  end;

begin
  // === CREAR VENTANA PRINCIPAL ===
  window := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title(GTK_WINDOW(window), PChar('Bandeja de Entrada - ' + LimpiarUTF8(usuario.email)));
  gtk_window_set_default_size(GTK_WINDOW(window), 700, 500);

  vbox := gtk_vbox_new(FALSE, 5);
  gtk_container_add(GTK_CONTAINER(window), vbox);

  // === SECCIÓN DE ORDENAMIENTO ===
  // Barra horizontal con botones de ordenamiento dinámico
  hboxOrden := gtk_hbox_new(FALSE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxOrden, FALSE, FALSE, 5);
  
  lblOrden := gtk_label_new('<b>Ordenar por:</b>');
  gtk_label_set_use_markup(GTK_LABEL(lblOrden), TRUE);
  gtk_box_pack_start(GTK_BOX(hboxOrden), lblOrden, FALSE, FALSE, 10);
  
  // Botón: Ordenar por asunto A-Z (Abel, Botella, Casa...)
  btnOrdenAZ := gtk_button_new_with_label('📝 Asunto A-Z');
  g_signal_connect(btnOrdenAZ, 'clicked', G_CALLBACK(@OnOrdenAZClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxOrden), btnOrdenAZ, FALSE, FALSE, 5);
  
  // Botón: Ordenar por asunto Z-A (Zebra, Yema, Xilófono...)
  btnOrdenZA := gtk_button_new_with_label('📝 Asunto Z-A');
  g_signal_connect(btnOrdenZA, 'clicked', G_CALLBACK(@OnOrdenZAClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxOrden), btnOrdenZA, FALSE, FALSE, 5);
  
  // Botón: Ordenar por fecha ascendente (más antiguos primero)
  btnOrdenFechaAsc := gtk_button_new_with_label('📅 Fecha ↑');
  g_signal_connect(btnOrdenFechaAsc, 'clicked', G_CALLBACK(@OnOrdenFechaAscClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxOrden), btnOrdenFechaAsc, FALSE, FALSE, 5);
  
  // Botón: Ordenar por fecha descendente (más recientes primero)
  btnOrdenFechaDesc := gtk_button_new_with_label('📅 Fecha ↓');
  g_signal_connect(btnOrdenFechaDesc, 'clicked', G_CALLBACK(@OnOrdenFechaDescClicked), nil);
  gtk_box_pack_start(GTK_BOX(hboxOrden), btnOrdenFechaDesc, FALSE, FALSE, 5);

  // === ÁREA DE TABLA CON SCROLL ===
  scroll := gtk_scrolled_window_new(nil, nil);
  gtk_box_pack_start(GTK_BOX(vbox), scroll, TRUE, TRUE, 0);

  // === CONFIGURAR TABLA (4 columnas) ===
  // Columnas: Remitente | Asunto | Fecha | Estado
  store := gtk_list_store_new(4, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);
  treeview := gtk_tree_view_new_with_model(GTK_TREE_MODEL(store));

  // Columna 0: Remitente
  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Remitente', renderer, 'text', 0, nil);
  gtk_tree_view_column_set_min_width(column, 150);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  // Columna 1: Asunto
  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Asunto', renderer, 'text', 1, nil);
  gtk_tree_view_column_set_min_width(column, 200);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  // Columna 2: Fecha
  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Fecha', renderer, 'text', 2, nil);
  gtk_tree_view_column_set_min_width(column, 100);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  // Columna 3: Estado
  renderer := gtk_cell_renderer_text_new;
  column := gtk_tree_view_column_new_with_attributes('Estado', renderer, 'text', 3, nil);
  gtk_tree_view_column_set_min_width(column, 80);
  gtk_tree_view_append_column(GTK_TREE_VIEW(treeview), column);

  gtk_container_add(GTK_CONTAINER(scroll), treeview);

  // === CONTENEDOR PARA BOTONES DE ACCIÓN ===
  hboxBotones := gtk_hbox_new(FALSE, 5);
  gtk_box_pack_start(GTK_BOX(vbox), hboxBotones, FALSE, FALSE, 5);

  // Botón: Mover correo seleccionado a papelera
  btnEliminar := gtk_button_new_with_label('🗑️ Mover a Papelera');
  g_signal_connect(btnEliminar, 'clicked', G_CALLBACK(@OnEliminarClicked), treeview);
  gtk_box_pack_start(GTK_BOX(hboxBotones), btnEliminar, FALSE, FALSE, 5);

  // === CARGAR DATOS INICIALES ===
  // Cargar correos del usuario sin ordenamiento (orden de llegada)
  CargarCorreosIniciales;

  // === CONFIGURAR EVENTOS ===
  // Doble clic en una fila → abre detalle del correo
  g_signal_connect(treeview, 'row-activated', G_CALLBACK(@OnRowActivated), nil);

  gtk_widget_show_all(window);
end;

end.