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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:portafirmas/model/sign_request.dart';

typedef RequestUpdatedCallback = void Function(SignRequest request);

/// Displays the request in any of the request list: unresolved, signed or rejected
/// [onRequestedUpdated] will be null in the case of signed or rejected requests
/// to indicate that the checkbox does not need to be painted.
class RequestItem extends StatefulWidget {
  final GestureTapCallback onTap;
  final RequestUpdatedCallback? onRequestUpdated;
  final SignRequest request;

  /// Stream used by the item to learn if the request has been read and needs
  /// to update its ui
  /// It will remain null if the request is already read on list update
  final Stream<String>? stream;

  const RequestItem({
    Key? key,
    required this.onTap,
    required this.onRequestUpdated,
    required this.request,
    this.stream,
  }) : super(key: key);

  @override
  RequestItemState createState() {
    return RequestItemState();
  }
}

class RequestItemState extends State<RequestItem> {
  // ignore: cancel_subscriptions
  StreamSubscription<String>? subscription;

  @override
  void initState() {
    super.initState();
    if (widget.stream != null) {
      subscription = widget.stream!.listen((requestId) {
        if (requestId == widget.request.id) {
          setState(() {
            widget.request.view = SignRequest.viewRead;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    if (subscription != null) {
      subscription!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isNew = widget.request.view == SignRequest.viewNew;
    return Material(
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 1.0,
                  color: Colors.grey[200]!,
                ),
              ),
              color: isNew ? Colors.grey[100] : Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 10.0),
          child: Row(
            children: [
              SizedBox(
                width: 25.0,
                child: Center(
                  child: widget.request.priority > 0 && widget.request.priority < 5
                      ? Image.asset('assets/images/icon_priority_${widget.request.priority}.png')
                      : null,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.subject!,
                        style: TextStyle(
                          fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                        ),
                        //overflow: TextOverflow.fade,
                      ),
                      const Padding(padding: EdgeInsets.only(top: 6.0)),
                      Text(
                        widget.request.sender,
                        style: TextStyle(
                          fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              //Expanded(child: Container()),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  widget.request.type == RequestType.signature
                      ? Transform.scale(
                          scale: 0.8,
                          child: Icon(Icons.vpn_key, color: Colors.teal[300]),
                        )
                      : Icon(Icons.check, color: Colors.teal[400]),
                  widget.onRequestUpdated == null
                      ? Container()
                      : Checkbox(
                          value: widget.request.selected,
                          onChanged: (selected) {
                            widget.request.selected = selected!;
                            setState(() {});
                            widget.onRequestUpdated!(widget.request);
                          },
                          visualDensity: const VisualDensity(horizontal: -4.0, vertical: 0.0),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
