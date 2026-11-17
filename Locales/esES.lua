-------------------------------------------------------------------------------
-- Tidy - Spanish translation (esES / esMX)
-- Key: English text · value: Spanish text
-------------------------------------------------------------------------------

local _, ns = ...

ns.translations.esES = {
    -- Commands

    -- Window
    ["Icons"] = "Iconos",
    ["Click again to confirm"] = "Haz clic otra vez para confirmar",
    ["Search..."] = "Buscar...",
    ["Accept"] = "Aceptar",
    ["Cancel"] = "Cancelar",

    -- Icons
    ["Where"] = "Dónde",
    ["Square icons with a flat border."] = "Iconos cuadrados con borde plano.",
    ["Enabled"] = "Activado",
    ["Action bars"] = "Barras de acción",
    ["Your buffs and debuffs"] = "Tus beneficios y perjuicios",
    ["Target and focus auras"] = "Auras del objetivo y el foco",
    ["Raid and party frame auras"] = "Auras de los marcos de banda y grupo",
    ["Blizzard's frames (Tile draws its own)."] = "Los marcos de Blizzard (Tile dibuja los suyos).",
    ["Items"] = "Objetos",
    ["Bags, bank, loot, merchant, character..."] = "Bolsas, banco, botín, vendedor, personaje...",
    ["Look"] = "Aspecto",
    ["Border thickness"] = "Grosor del borde",
    ["Border color"] = "Color del borde",
    ["Zoom"] = "Zoom",
    ["Background"] = "Fondo",
    ["Seen on empty buttons. Lower its opacity to make it lighter or invisible."] =
        "Se ve en los botones vacíos. Baja su opacidad para aclararlo o hacerlo invisible.",
    ["How much of the icon edge is cut off. Blizzard icons have a bevel around 8%."] =
        "Cuánto se recorta del borde del icono. Los iconos de Blizzard tienen un bisel de un 8% aprox.",
    ["Debuff type color"] = "Color por tipo de perjuicio",
    ["Debuff border by type (magic, curse, poison...) instead of the chosen color."] =
        "Borde de los perjuicios según su tipo (magia, maldición, veneno...) en vez del color elegido.",
    ["Item quality color"] = "Color por calidad del objeto",
    ["Item border by rarity (green, blue, purple...) instead of the chosen color."] =
        "Borde de los objetos según su rareza (verde, azul, morado...) en vez del color elegido.",
    ["Defaults"] = "Valores por defecto",

    -- Profiles
    ["Profiles"] = "Perfiles",
    ["Profile: %s"] = "Perfil: %s",
    ["This character"] = "Este personaje",
    ["One profile holds every setting. Several characters can share it."] =
        "Un perfil guarda todos los ajustes. Varios personajes pueden compartirlo.",
    ["Profile in use"] = "Perfil en uso",
    ["New profile"] = "Nuevo perfil",
    ["Type a name and press Enter: a new profile with the default settings."] =
        "Escribe un nombre y pulsa Intro: un perfil nuevo con los ajustes por defecto.",
    ["Copy and reset"] = "Copiar y restablecer",
    ["Copy from"] = "Copiar de",
    ["Copy into this profile"] = "Copiar en este perfil",
    ["Reset this profile"] = "Restablecer este perfil",
    ["Delete profile"] = "Borrar perfil",
    ["Delete"] = "Borrar",
    ["Share"] = "Compartir",
    ["Export this profile as text, or paste one to import it."] =
        "Exporta este perfil como texto, o pega uno para importarlo.",
    ["Export"] = "Exportar",
    ["Import"] = "Importar",
    ["Copied to the box: press Ctrl+C."] = "Copiado en el cuadro: pulsa Ctrl+C.",
    ["This replaces every setting of the profile in use. Continue?"] =
        "Esto reemplaza todos los ajustes del perfil en uso. ¿Continuar?",
    ["Profile imported."] = "Perfil importado.",
    ["This is not a Tidy profile."] = "Esto no es un perfil de Tidy.",
    ["The text is damaged."] = "El texto está dañado.",

    -- General
    ["General"] = "General",
    ["Editing"] = "Edición",
    ["Keybinding mode"] = "Modo de atajos",
    ["Unlock bars (top of the window) and drag a bar to move it, or click it to edit it."] =
        "Desbloquea las barras (arriba en la ventana) y arrastra una barra para moverla, o haz clic para editarla.",
    ["Presets"] = "Plantillas",
    ["Layout"] = "Disposición",
    ["Blizzard-like"] = "Como Blizzard",
    ["Compact"] = "Compacta",
    ["Split"] = "Dividida",
    ["Places the action bars 1 and 3-6 in a ready layout (position, rows, padding, scale). The other settings stay."] =
        "Coloca las barras de acción 1 y 3-6 en una disposición lista (posición, filas, espaciado, escala). El resto de ajustes se mantiene.",
    ["Gryphons"] = "Grifos",
    ["Blizzard's gryphons (wyverns for the Horde) at the sides of bar 1."] =
        "Los grifos de Blizzard (dracoleones para la Horda) a los lados de la barra 1.",
    ["Minimap button"] = "Botón del minimapa",
    ["Profile"] = "Perfil",
    ["Click"] = "Clic",
    ["Right click"] = "Clic derecho",
    ["Drag"] = "Arrastrar",
    ["Open the options"] = "Abrir las opciones",
    ["Move this button"] = "Mover este botón",

    ["Addon"] = "Addon",
    ["Language"] = "Idioma",
    ["Reset this bar"] = "Restablecer esta barra",
    ["Move 0.5 px. Shift-click: 5 px."] = "Mover 0,5 px. Mayús+clic: 5 px.",
    ["Every setting of this bar back to its default, position included."] =
        "Todos los ajustes de esta barra a sus valores por defecto, posición incluida.",

    -- Tabs and card titles
    ["Size"] = "Tamaño",
    ["Arrangement"] = "Disposición de botones",
    ["Fade"] = "Desvanecer",
    ["Hide"] = "Ocultar",
    ["Paging"] = "Páginas",
    ["Actions"] = "Acciones",
    ["This bar's buttons"] = "Botones de esta barra",
    ["Which page of actions the bar shows. Action bars only."] =
        "Qué página de acciones muestra la barra. Solo barras de acción.",
    ["What the buttons of this bar show. Action bars only."] =
        "Qué muestran los botones de esta barra. Solo barras de acción.",
    ["For every button of Tidy's action bars."] = "Para todos los botones de las barras de acción de Tidy.",
    ["Self-cast"] = "Lanzar sobre ti",
    ["Focus"] = "Foco",
    ["Mouse-over"] = "Bajo el ratón",

    ["Modifier keys"] = "Teclas modificadoras",
    ["While the key is held, the bar shows another page."] =
        "Mientras mantienes la tecla, la barra muestra otra página.",
    ["Flyouts"] = "Desplegables",
    ["Menus that open from a button (portals, totems, pets...)."] =
        "Menús que se abren desde un botón (portales, tótems, mascotas...).",
    ["Show"] = "Mostrar",


    ["Hide in a stance or form"] = "Ocultar en una postura o forma",
    ["Center horizontally"] = "Centrar en horizontal",
    ["Center vertically"] = "Centrar en vertical",
    ["This bar only"] = "Solo de esta barra",
    ["Only the backpack"] = "Solo la mochila",
    ["Keyring"] = "Llavero",
    ["Hide the artwork"] = "Ocultar el adorno",
    ["The decorative frame around the extra button and the zone ability."] =
        "El marco decorativo del botón extra y de la habilidad de zona.",

    ["Unlock bars"] = "Desbloquear barras",
    ["Drag a bar to move it, click it to edit it."] = "Arrastra una barra para moverla, haz clic para editarla.",
    ["Hover a button and press a key. Esc to leave."] = "Pasa el ratón por un botón y pulsa una tecla. Esc para salir.",

    ["Where button 1 is and which way the others follow. The bar does not move."] =
        "Dónde está el botón 1 y hacia dónde siguen los demás. La barra no se mueve.",
    ["Which row comes first. Only with more than one row."] = "Qué fila va primero. Solo con más de una fila.",

    ["Flat"] = "Plano",
    ["Blizzard"] = "Blizzard",
    ["Hover"] = "Al pasar el ratón",
    ["Pressed"] = "Pulsado",
    ["Active"] = "Activo",

    ["Button"] = "Botón",

    -- Keybinding mode
    ["no key"] = "sin tecla",
    ["Press a key to bind it"] = "Pulsa una tecla para asignarla",
    ["Esc: leave · Delete: clear"] = "Esc: salir · Supr: borrar",
    ["Keybinding mode: hover a button and press a key. Esc to leave."] =
        "Modo de atajos: pasa el ratón por un botón y pulsa una tecla. Esc para salir.",

    -- Bar page
    ["Button width"] = "Anchura del botón",
    ["Button height"] = "Altura del botón",
    ["Icon"] = "Icono",
    ["Cover"] = "Cubrir",
    ["Contain"] = "Contener",
    ["Stretch"] = "Estirar",
    ["Cover: fills the button, cropped. Contain: the whole icon, centered. Stretch: fills it, deformed."] =
        "Cubrir: llena el botón, recortado. Contener: el icono entero, centrado. Estirar: lo llena, deformado.",
    ["Fill"] = "Rellenar",
    ["To the right"] = "Hacia la derecha",
    ["To the left"] = "Hacia la izquierda",
    ["Downwards"] = "Hacia abajo",
    ["Upwards"] = "Hacia arriba",
    ["Click-through"] = "Atravesable por el ratón",
    ["The mouse goes through the buttons (keybinds still work)."] =
        "El ratón atraviesa los botones (los atajos siguen funcionando).",
    ["X position"] = "Posición X",
    ["Y position"] = "Posición Y",
    ["From the bottom left corner of the screen to the top left corner of the bar."] =
        "Desde la esquina inferior izquierda de la pantalla hasta la esquina superior izquierda de la barra.",
    ["Visibility"] = "Visibilidad",
    ["Fade out when the mouse is not over it"] = "Desvanecer cuando el ratón no está encima",
    ["Faded opacity"] = "Opacidad desvanecida",
    ["Delay"] = "Retraso",
    ["Hide in combat"] = "Ocultar en combate",
    ["Hide out of combat"] = "Ocultar fuera de combate",
    ["Hide with a pet"] = "Ocultar con mascota",
    ["Hide without a pet"] = "Ocultar sin mascota",
    ["Hide in vehicles"] = "Ocultar en vehículos",
    ["Custom conditions"] = "Condiciones propias",
    ["Macro conditions, e.g. [combat] show; hide. When set, they replace the options above."] =
        "Condiciones de macro, p. ej. [combat] show; hide. Si las pones, sustituyen a las opciones de arriba.",
    ["Page"] = "Página",
    ["Page %d"] = "Página %d",
    ["None"] = "Ninguna",
    ["Warrior stances, druid forms, rogue stealth, priest shadowform: pages 7 to 10."] =
        "Posturas de guerrero, formas de druida, sigilo de pícaro, forma de las sombras: páginas 7 a 10.",
    ["Page with Ctrl"] = "Página con Ctrl",
    ["Page with Alt"] = "Página con Alt",
    ["Page with Shift"] = "Página con Mayús",
    ["Hide macro names"] = "Ocultar nombres de macro",
    ["Hide keybinds"] = "Ocultar atajos",
    ["Hide equipped border"] = "Ocultar borde de equipado",
    ["Flyout direction"] = "Dirección del desplegable",
    ["Up"] = "Arriba",
    ["Down"] = "Abajo",
    ["Left"] = "Izquierda",
    ["Right"] = "Derecha",

    -- Buttons page
    ["Behaviour"] = "Comportamiento",
    ["Tooltips"] = "Descripciones emergentes",
    ["Always"] = "Siempre",
    ["Out of combat"] = "Fuera de combate",
    ["Never"] = "Nunca",
    ["Out of range"] = "Fuera de alcance",
    ["Pressed on cooldown"] = "Pulsado en reutilización",
    ["A bright line that follows the global cooldown as it turns."] =
        "Una línea brillante que acompaña al tiempo de reutilización global mientras gira.",
    ["Pressed when not usable"] = "Pulsado sin poder usarse",
    ["Pressed on an empty slot"] = "Pulsado en un hueco vacío",
    ["Pressed on global cooldown"] = "Pulsado en reutilización global",
    ["Lock buttons"] = "Bloquear botones",
    ["Spells cannot be dragged off the bars (Shift + drag still can)."] =
        "Los hechizos no se pueden sacar de las barras (Mayús + arrastrar sí).",
    ["Style"] = "Estilo",
    ["Interrupted"] = "Interrumpido",
    ["Cast on key down"] = "Lanzar al pulsar la tecla",
    ["A game setting: for every bar."] = "Un ajuste del juego: para todas las barras.",
    ["Self-cast with a key"] = "Lanzar sobre ti con una tecla",
    ["Self-cast key"] = "Tecla para lanzar sobre ti",
    ["Focus-cast with a key"] = "Lanzar al foco con una tecla",
    ["Focus-cast key"] = "Tecla para lanzar al foco",
    ["Mouse-over casting"] = "Lanzar bajo el ratón",
    ["Spells go to the unit under the mouse."] = "Los hechizos van a la unidad bajo el ratón.",
    ["Mouse-over key"] = "Tecla para lanzar bajo el ratón",
    ["Right click casts on yourself"] = "Clic derecho lanza sobre ti",
    ["Texts"] = "Textos",
    ["Keybind"] = "Atajo",
    ["Count"] = "Cantidad",
    ["Macro name"] = "Nombre de macro",
    ["Cooldown"] = "Reutilización",
    ["Font"] = "Fuente",
    ["Outline"] = "Contorno",
    ["Thick outline"] = "Contorno grueso",
    ["Color"] = "Color",
    ["Position"] = "Posición",
    ["X offset"] = "Desplazamiento X",
    ["Y offset"] = "Desplazamiento Y",
    ["Top left"] = "Arriba izquierda",
    ["Top"] = "Arriba",
    ["Top right"] = "Arriba derecha",
    ["Center"] = "Centro",
    ["Bottom left"] = "Abajo izquierda",
    ["Bottom"] = "Abajo",
    ["Bottom right"] = "Abajo derecha",
    ["Tidy and Blizzard bars, pet and stance bars."] =
        "Barras de Tidy y de Blizzard, de mascota y de posturas.",

    -- Bars
    ["%s is loaded: Tidy's bars stay off. Disable one of them and reload."] =
        "%s está cargado: las barras de Tidy se quedan desactivadas. Desactiva uno de los dos y recarga.",
    ["Bars"] = "Barras",
    ["Bar %d"] = "Barra %d",
    ["Your spells and keybinds, on bars you place. Replaces Blizzard's action bars."] =
        "Tus hechizos y atajos, en barras que colocas tú. Sustituye a las barras de acción de Blizzard.",
    ["Lock / unlock bars"] = "Bloquear / desbloquear barras",
    ["Snap while moving"] = "Imantar al mover",
    ["A bar you drag sticks to the edges and centers of other bars, the screen center lines and the screen borders."] =
        "La barra que arrastras se pega a los bordes y centros de otras barras, a las líneas centrales de la pantalla y a sus bordes.",
    ["Show this bar"] = "Mostrar esta barra",
    ["Pet bar"] = "Barra de mascota",
    ["Stance bar"] = "Barra de posturas",
    ["Micro menu"] = "Micromenú",
    ["Bags"] = "Bolsas",
    ["XP / reputation"] = "PX / reputación",
    ["Extra button"] = "Botón extra",
    ["Leave vehicle"] = "Salir del vehículo",
    ["Queue status"] = "Estado de cola",
    ["Width"] = "Anchura",
    ["Buttons"] = "Botones",
    ["Rows"] = "Filas",
    ["Padding"] = "Espaciado",
    ["Scale"] = "Escala",
    ["Opacity"] = "Opacidad",
    ["Show empty buttons"] = "Mostrar botones vacíos",
    ["Change page with stance / form"] = "Cambiar de página con postura / forma",
    -- Buttons: states, timers, flashes, texts
    ["States"] = "Estados",
    ["Timers"] = "Tiempos",
    ["Flashes"] = "Destellos",
    ["Attacking"] = "Atacando",
    ["Auto-repeat"] = "Repetición automática",
    ["Out of mana"] = "Sin maná",
    ["Not usable"] = "No utilizable",
    ["Equipped"] = "Equipado",
    ["Tints"] = "Tiñe",
    ["Global cooldown"] = "Reutilización global",
    ["Casting"] = "Lanzando",
    ["Darkness"] = "Oscuridad",
    ["Spark"] = "Destello",
    ["Ready"] = "Listo",
    ["Macro"] = "Macro",
    ["If the game does not tell it is the global cooldown, the cooldown darkness is used."] =
        "Si el juego no indica que es la reutilización global, se usa la oscuridad de la reutilización.",
    ["Flat: the button fills as the cast goes (a channel empties); the color is the fill. Blizzard: the game's animation."] =
        "Plano: el botón se llena mientras lanzas (una canalización se vacía); el color es el relleno. Blizzard: la animación del juego.",
    ["No target, out of range, not enough power, not usable..."] =
        "Sin objetivo, fuera de alcance, sin recurso suficiente, no utilizable...",
    ["Also where empty slots are hidden."] = "También donde los huecos vacíos están ocultos.",
    ["When a cooldown of 2 seconds or more ends."] = "Cuando termina una reutilización de 2 segundos o más.",
    ["With the flat cast animation (Timers, Casting)."] = "Con la animación de lanzamiento plana (Tiempos, Lanzando).",
    ["Can also be hidden per bar (Bars, Actions tab)."] = "También se puede ocultar por barra (Barras, pestaña Acciones).",
    ["A bright line on the moving edge of the fill."] = "Una línea brillante en el borde que avanza del relleno.",
    ["The Blizzard style plays only on the bars: the game starts it from a real cast."] =
        "El estilo Blizzard solo se ve en las barras: el juego lo inicia con un lanzamiento real.",
    ["With square icons on action bars (Icons)."] = "Con iconos cuadrados en las barras de acción (Iconos).",
    ["Every setting of this tab back to its default."] = "Todos los ajustes de esta pestaña a sus valores por defecto.",
    ["The look back to its defaults (the places stay)."] = "El aspecto a sus valores por defecto (los lugares se mantienen).",
}
ns.translations.esMX = ns.translations.esES
