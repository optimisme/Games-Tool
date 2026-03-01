import 'utils_gamestool/utils_gamestool.dart';

class Camera {
  double x = 500;
  double y = 500;
  double focal = 500; // Amplada visible del món

  RuntimeCamera2D toRuntimeCamera2D() {
    return RuntimeCamera2D(x: x, y: y, focal: focal);
  }
}
