// 파일 목적: 모든 도구의 기본 클래스, 예외, 인터페이스 정의
// 9개 도구 함수가 공유하는 예외처리 및 기본 구조

/// 도구 실행 기본 예외 클래스
abstract class ToolException implements Exception {
  final String message;
  ToolException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// 입력 값 검증 실패 예외
/// 예: 잘못된 형식, 필수 필드 누락, 값 범위 초과
class ValidationException extends ToolException {
  ValidationException(super.message);
}

/// 네트워크 오류 예외
/// Claude API 호출 실패 시 발생, 자동 재시도 (3회) 수행
class NetworkException extends ToolException {
  final int retryCount;
  NetworkException(super.message, {this.retryCount = 0});
}

/// 데이터베이스/파일 시스템 오류 예외
/// Hive 저장/읽기 실패, 파일 파싱 오류 등
class DatabaseException extends ToolException {
  DatabaseException(super.message);
}

/// 접근 거부 예외
/// visibility="private" 기록에 현재 사용자가 접근할 때 발생
class AccessDeniedException extends ToolException {
  AccessDeniedException(super.message);
}

/// 파일 읽기 오류 예외
class FileException extends ToolException {
  final String? filePath;
  FileException(super.message, {this.filePath});
}

/// 도구 실행 컨텍스트
/// 각 도구에는 현재 사용자 정보, Hive 박스 참조 등이 필요
class ToolContext {
  /// 현재 실행 중인 사용자 ID
  final String currentUserId;

  /// 도구 실행 타임아웃 (밀리초)
  final Duration timeout;

  /// 네트워크 재시도 횟수
  final int maxRetries;

  ToolContext({
    required this.currentUserId,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
  });
}

/// 도구 실행 결과 (성공/실패)
sealed class ToolResult<T> {
  const ToolResult();

  /// 성공 결과
  factory ToolResult.success(T data) = ToolSuccess<T>;

  /// 실패 결과
  factory ToolResult.failure(ToolException exception) = ToolFailure<T>;

  /// 결과에서 데이터 추출 (실패 시 예외)
  T getOrThrow() => switch (this) {
        ToolSuccess<T>(:final data) => data,
        ToolFailure<T>(:final exception) => throw exception,
      };

  /// 결과 매핑
  ToolResult<U> map<U>(U Function(T) transform) => switch (this) {
        ToolSuccess<T>(:final data) => ToolSuccess<U>(transform(data)),
        ToolFailure<T>(:final exception) => ToolFailure<U>(exception),
      };
}

/// 성공 결과
class ToolSuccess<T> extends ToolResult<T> {
  final T data;
  const ToolSuccess(this.data);
}

/// 실패 결과
class ToolFailure<T> extends ToolResult<T> {
  final ToolException exception;
  const ToolFailure(this.exception);
}
