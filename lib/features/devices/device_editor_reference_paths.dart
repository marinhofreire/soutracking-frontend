// SVG paths from the approved preview.
const deviceEditorReferencePaths = <String, String>{
  'grid': 'M3 3h6v6H3z M15 3h6v6h-6z M3 15h6v6H3z M15 15h6v6h-6z',
  'car': 'M5 10l2-5h10l2 5 M3 10h18v8H3z M6 18v3 M18 18v3 M6 14h2 M16 14h2',
  'chip':
      'M6 6h12v12H6z M9 9h6v6H9z M9 2v4 M15 2v4 M9 18v4 M15 18v4 M2 9h4 M2 15h4 M18 9h4 M18 15h4',
  'tune': 'M4 3v18 M12 3v18 M20 3v18 M1 8h6 M9 16h6 M17 9h6',
  'check': 'M9 12l2 2 4-4 M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0',
  'chevron': 'M9 5l7 7-7 7',
  'close': 'M6 6l12 12 M6 18L18 6',
  'plus': 'M12 5v14 M5 12h14',
  'image': 'M3 3h18v18H3z M3 17l6-6 4 4 3-3 5 5 M15 7h.1',
  'save': 'M4 3h13l3 3v15H4z M8 3v6h8V3 M8 14h8v7',
  'refresh': 'M20 8a8 8 0 1 0 0 8 M20 3v5h-5',
  'settings':
      'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8 M12 2v3 M12 19v3 M2 12h3 M19 12h3 M5 5l2 2 M17 17l2 2 M5 19l2-2 M17 7l2-2',
  'map': 'M3 4l6-2 6 2 6-2v18l-6 2-6-2-6 2z M9 2v18 M15 4v18',
  'chart': 'M4 20V10 M10 20V4 M16 20v-7 M2 21h20',
  'headset':
      'M4 14v-2a8 8 0 0 1 16 0v2 M3 12h4v7H3z M17 12h4v7h-4z M20 19c0 3-4 3-6 3',
  'alert': 'M12 3L2 21h20z M12 9v5 M12 17h.1',
  'video': 'M3 6h12v12H3z M15 10l6-3v10l-6-3',
  'wallet': 'M3 5h17v15H3z M3 5V3h14 M15 10h6v6h-6z',
  'clock': 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0 M12 7v5l3 2',
  'power': 'M12 2v9 M6 5a9 9 0 1 0 12 0',
  'sensor':
      'M8 8a6 6 0 0 0 0 8 M4 4a11 11 0 0 0 0 16 M16 8a6 6 0 0 1 0 8 M20 4a11 11 0 0 1 0 16 M12 11v2',
  'door': 'M5 3h14v18H5z M15 12h.1',
  'lock': 'M5 10h14v11H5z M8 10V6a4 4 0 0 1 8 0v4',
  'battery': 'M2 7h18v10H2z M22 10v4 M6 10v4 M10 10v4 M14 10v4',
  'signal': 'M5 18v3 M10 13v8 M15 8v13 M20 3v18',
  'route': 'M5 4v10a5 5 0 0 0 10 0V7 M2 4h6 M12 7h6',
  'download': 'M12 3v12 M7 10l5 5 5-5 M3 17v4h18v-4',
  'search': 'M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14 M15 15l6 6',
  'truck':
      'M2 5h12v12H2z M14 10h4l4 4v3h-8 M6 21a2 2 0 1 0 0-4 2 2 0 0 0 0 4 M18 21a2 2 0 1 0 0-4 2 2 0 0 0 0 4',
  'person': 'M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8 M4 21v-3a8 8 0 0 1 16 0v3',
  'boat': 'M3 14l9-4 9 4-3 6H6z M12 2v8 M12 3l6 5h-6',
  'bike':
      'M5 21a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M19 21a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M5 17l5-9 4 9h-9 M10 8h6 M16 5l3 12',
  'plane': 'M12 2v20 M12 7L2 15v3l10-4 10 4v-3z',
  'filter': 'M3 4h18l-7 8v7l-4 2V12z',
};
