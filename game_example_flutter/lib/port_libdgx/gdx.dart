import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'input_state.dart';

class Gdx {
  static final Input input = Input();
  static final Graphics graphics = Graphics();
  static final App app = App();
}

class App {
  void error(String tag, String message, [Object? error]) {
    // ignore: avoid_print
    print('[$tag] $message ${error ?? ''}');
  }

  void log(String tag, String message) {
    // ignore: avoid_print
    print('[$tag] $message');
  }
}

class Graphics {
  double _deltaTime = 0;
  int _width = 1;
  int _height = 1;
  ui.Canvas? _canvas;

  double getDeltaTime() => _deltaTime;

  int getWidth() => _width;

  int getHeight() => _height;

  ui.Canvas getCanvas() {
    final ui.Canvas? canvas = _canvas;
    if (canvas == null) {
      throw StateError('No active canvas in this frame');
    }
    return canvas;
  }

  void beginFrame(ui.Canvas canvas, int width, int height, double deltaTime) {
    _canvas = canvas;
    _width = width <= 0 ? 1 : width;
    _height = height <= 0 ? 1 : height;
    _deltaTime = deltaTime;
  }

  void endFrame() {
    _canvas = null;
  }
}

class Input {
  static final _KeysData Keys = _KeysData();
  static final _ButtonsData Buttons = _ButtonsData();

  final InputState _state = InputState();

  void onKeyDown(int keycode) {
    _state.onKeyDown(keycode);
  }

  void onKeyUp(int keycode) {
    _state.onKeyUp(keycode);
  }

  void onPointerDown(double x, double y) {
    _state.onPointerDown(x, y);
  }

  void onPointerMove(double x, double y) {
    _state.onPointerMove(x, y);
  }

  void onPointerUp(double x, double y) {
    _state.onPointerUp(x, y);
  }

  bool isKeyPressed(int keycode) => _state.isKeyPressed(keycode);

  bool isKeyJustPressed(int keycode) => _state.isKeyJustPressed(keycode);

  bool justTouched() => _state.justTouched();

  int getX() => _state.getX();

  int getY() => _state.getY();

  void endFrame() {
    _state.endFrame();
  }

  void setInputProcessor(Object? _processor) {}
}

class _KeysData {
  final int UP = 19;
  final int DOWN = 20;
  final int LEFT = 21;
  final int RIGHT = 22;
  final int W = 51;
  final int A = 29;
  final int S = 47;
  final int D = 32;
  final int ENTER = 66;
  final int SPACE = 62;
  final int ESCAPE = 111;
  final int F3 = 292;
  final int SHIFT_LEFT = 59;
  final int SHIFT_RIGHT = 60;
  final int R = 46;
}

class _ButtonsData {
  final int LEFT = 0;
}

int? logicalKeyToGdxKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowUp) {
    return Input.Keys.UP;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    return Input.Keys.DOWN;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return Input.Keys.LEFT;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return Input.Keys.RIGHT;
  }
  if (key == LogicalKeyboardKey.escape) {
    return Input.Keys.ESCAPE;
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    return Input.Keys.ENTER;
  }
  if (key == LogicalKeyboardKey.space) {
    return Input.Keys.SPACE;
  }
  if (key == LogicalKeyboardKey.f3) {
    return Input.Keys.F3;
  }
  if (key == LogicalKeyboardKey.shiftLeft) {
    return Input.Keys.SHIFT_LEFT;
  }
  if (key == LogicalKeyboardKey.shiftRight) {
    return Input.Keys.SHIFT_RIGHT;
  }

  if (key == LogicalKeyboardKey.keyW) {
    return Input.Keys.W;
  }
  if (key == LogicalKeyboardKey.keyA) {
    return Input.Keys.A;
  }
  if (key == LogicalKeyboardKey.keyS) {
    return Input.Keys.S;
  }
  if (key == LogicalKeyboardKey.keyD) {
    return Input.Keys.D;
  }
  if (key == LogicalKeyboardKey.keyR) {
    return Input.Keys.R;
  }
  return null;
}
