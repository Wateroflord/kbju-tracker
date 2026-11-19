/// Счётчик отжиманий по углу в локтях. Чистый Dart — без камеры, поэтому его легко проверить тестами.
///
/// Как считается одно отжимание:
///   1. руки прямые (угол в локтях ≥ [upAngle]);
///   2. опускаешься, пока угол не станет ≤ [downAngle] (это примерно 90°);
///   3. снова выпрямляешь руки до ≥ [upAngle] → +1.
/// Если не опустился достаточно низко — подсказка «Ниже!».
/// Если внизу не выпрямил руки до конца и опять пошёл вниз — подсказка «Выпрями руки!».
/// Повторы быстрее [minRepMs] не засчитываются (защита от дёрганья).
library;

enum RepHint { none, lower, straighten, tooFast }

class RepCounter {
  static const double downAngle = 95; // локоть согнут примерно до 90°
  static const double upAngle = 155; // руки выпрямлены
  static const int minRepMs = 500; // быстрее полсекунды — не засчитываем

  /// Засчитанные отжимания.
  int reps = 0;

  /// Незасчитанные (неправильные или слишком быстрые) повторы.
  int rejected = 0;

  /// Последняя подсказка для экрана.
  RepHint hint = RepHint.none;

  /// Счёт начинается только после того, как увидели прямые руки (упор лёжа).
  bool ready = false;

  bool _down = false; // нижняя точка уже достигнута
  bool _bending = false; // начал сгибать руки сверху, но ещё не дошёл до низа
  bool _risen = false; // внизу начал подниматься, но не выпрямил руки
  int _lastRepMs = -100000;

  /// Передать новый угол (в градусах) и время в миллисекундах.
  /// Возвращает true, если засчитано новое отжимание.
  bool update(double angle, int ms) {
    if (!ready) {
      if (angle >= upAngle) ready = true;
      return false;
    }

    if (!_down) {
      if (angle <= downAngle) {
        // дошёл до низа
        _down = true;
        _bending = false;
        _risen = false;
        hint = RepHint.none;
      } else if (angle < upAngle - 15) {
        _bending = true;
      } else if (angle >= upAngle && _bending) {
        // согнул руки чуть-чуть и вернулся наверх — не засчитываем
        _bending = false;
        rejected++;
        hint = RepHint.lower;
      }
      return false;
    }

    // сейчас внизу
    if (angle >= upAngle) {
      _down = false;
      _bending = false;
      _risen = false;
      if (ms - _lastRepMs < minRepMs) {
        rejected++;
        hint = RepHint.tooFast;
        return false;
      }
      _lastRepMs = ms;
      reps++;
      hint = RepHint.none;
      return true;
    }
    if (angle > downAngle + 25) {
      _risen = true;
    } else if (_risen && angle <= downAngle) {
      // поднялся наполовину и снова вниз — руки не выпрямлены
      _risen = false;
      rejected++;
      hint = RepHint.straighten;
    }
    return false;
  }

  /// Время последнего засчитанного отжимания (мс) или null.
  int? get lastRepMs => reps == 0 ? null : _lastRepMs;

  void reset() {
    reps = 0;
    rejected = 0;
    hint = RepHint.none;
    ready = false;
    _down = false;
    _bending = false;
    _risen = false;
    _lastRepMs = -100000;
  }
}

String hintText(RepHint h) => switch (h) {
      RepHint.none => '',
      RepHint.lower => 'Ниже!',
      RepHint.straighten => 'Выпрями руки!',
      RepHint.tooFast => 'Слишком быстро!',
    };
