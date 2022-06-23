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

import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

/// A builder function that creates a list of reactions
typedef ReactionsBuilderFunction = List<ReactionDisposer> Function(BuildContext context);

/// ReactionsBuilder is similar to [ReactionBuilder] from the flutter mobx package
/// but allows to trigger several reactions instead of just one.
///
/// Although simple, this little helper Widget eliminates the need to create a stateful
/// widget and handles the lifetime of reactions correctly. To use it, pass a
/// [builder] that takes in a [BuildContext] and prepares the list of reactions. It should
/// end up returning a list of [ReactionDisposer]. This will be disposed when the [ReactionsBuilder]
/// is disposed. The [child] Widget gets rendered as part of the build process.
class ReactionsBuilder extends StatefulWidget {
  final ReactionsBuilderFunction builder;
  final Widget child;

  const ReactionsBuilder({Key? key, required this.child, required this.builder}) : super(key: key);

  @override
  ReactionsBuilderState createState() => ReactionsBuilderState();
}

@visibleForTesting
class ReactionsBuilderState extends State<ReactionsBuilder> {
  late List<ReactionDisposer> _disposeReactions;

  bool get isDisposed {
    for (var disposeReaction in _disposeReactions) {
      if (!disposeReaction.reaction.isDisposed) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();

    _disposeReactions = widget.builder(context);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    for (var disposeReaction in _disposeReactions) {
      disposeReaction();
    }
    super.dispose();
  }
}
