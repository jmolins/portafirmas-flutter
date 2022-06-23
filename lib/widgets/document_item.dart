/*
    Copyright 2022. Chema Molins.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

import 'package:flutter/material.dart';

/// Tipos de documento
enum DocumentType {
  /// Documento
  document,

  /// Attachment
  attachment,

  /// Firma.
  signature,

  /// REPORT.
  report
}

class DocumentItem extends StatefulWidget {
  final String name;
  final String mimetype;
  final int size;
  final DocumentType type;
  final GestureTapCallback onTap;

  const DocumentItem(
      {Key? key,
      required this.name,
      required this.mimetype,
      required this.size,
      required this.type,
      required this.onTap})
      : super(key: key);

  @override
  State<DocumentItem> createState() => _DocumentItemState();
}

class _DocumentItemState extends State<DocumentItem> {
  @override
  Widget build(BuildContext context) {
    Color titleColor = widget.type == DocumentType.document ? Colors.black : Colors.black54;
    return Material(
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 60.0,
                child: Center(
                  child: _getIconForFile(widget.name.toLowerCase()),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                      ),
                    ),
                    widget.type == DocumentType.document || widget.type == DocumentType.attachment
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4.0, left: 0.0),
                            child: Text('Tamaño: ${_formatFileSize(widget.size)}',
                                style: const TextStyle(fontSize: 12.0, color: Colors.black54)),
                          )
                        : Container(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _getIconForFile(String filename) {
  String prefix = 'generic';
  if (filename.endsWith('.pdf')) {
    prefix = 'pdf';
  } else if (filename.endsWith('.doc') || filename.endsWith('.docx')) {
    prefix = 'doc';
  } else if (filename.endsWith('.xls') || filename.endsWith('.xlsx')) {
    prefix = 'xls';
  } else if (filename.endsWith('.ppt') || filename.endsWith('.pptx')) {
    prefix = 'ppt';
  } else if (filename.endsWith('.jpg') ||
      filename.endsWith('.jpeg') ||
      filename.endsWith('.png') ||
      filename.endsWith('.gif')) {
    prefix = 'image';
  } else if (filename.endsWith('.txt')) {
    prefix = 'txt';
  } else if (filename.endsWith('.mp3')) {
    prefix = 'audio';
  } else if (filename.endsWith('.mp4')) {
    prefix = 'video';
  } else if (filename.endsWith('.xml')) {
    prefix = 'xml';
  } else if (filename.endsWith('.zip') || filename.endsWith('.7zip') || filename.endsWith('.rar')) {
    prefix = 'archive';
  } else {
    prefix = 'generic';
  }
  return Image.asset('assets/images/${prefix}_file.png', width: 30.0);
}

String _formatFileSize(final int fileSize) {
  if (fileSize < 1024) {
    return '${addDotMiles(fileSize)} bytes';
  } else if (fileSize / 1024 < 1024) {
    return '${addDotMiles(fileSize ~/ 1024)} KB';
  } else {
    final double kbs = fileSize / 1024;
    String fraction = (kbs % 1024).toString();
    if (fraction.length > 2) {
      fraction = fraction.substring(0, 2);
    }
    return '${addDotMiles(kbs ~/ 1024)},$fraction  MB';
  }
}

String addDotMiles(final int number) {
  final String nString = number.toString();
  final StringBuffer buffer = StringBuffer();
  if (nString.length > 3) {
    int dotPos = nString.length % 3;
    if (dotPos > 0) {
      buffer.write(nString.substring(0, dotPos));
    }
    while (dotPos < nString.length) {
      if (dotPos > 0) {
        buffer.write('.');
      }
      buffer.write(nString.substring(dotPos, dotPos + 3));
      dotPos += 3;
    }
  } else {
    buffer.write(nString);
  }
  return buffer.toString();
}
