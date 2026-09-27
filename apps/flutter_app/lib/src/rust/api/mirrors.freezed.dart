// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mirrors.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ApiError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError()';
}


}

/// @nodoc
class $ApiErrorCopyWith<$Res>  {
$ApiErrorCopyWith(ApiError _, $Res Function(ApiError) __);
}


/// Adds pattern-matching-related methods to [ApiError].
extension ApiErrorPatterns on ApiError {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ApiError_NotImplemented value)?  notImplemented,TResult Function( ApiError_InvalidSession value)?  invalidSession,TResult Function( ApiError_InvalidHandle value)?  invalidHandle,TResult Function( ApiError_StalePayload value)?  stalePayload,TResult Function( ApiError_VaultLocked value)?  vaultLocked,TResult Function( ApiError_ProviderUnavailable value)?  providerUnavailable,TResult Function( ApiError_OpenSuggestions value)?  openSuggestions,TResult Function( ApiError_ImportRefused value)?  importRefused,TResult Function( ApiError_BadSpan value)?  badSpan,TResult Function( ApiError_UnknownToken value)?  unknownToken,TResult Function( ApiError_NothingToSend value)?  nothingToSend,TResult Function( ApiError_PayloadRefused value)?  payloadRefused,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ApiError_NotImplemented() when notImplemented != null:
return notImplemented(_that);case ApiError_InvalidSession() when invalidSession != null:
return invalidSession(_that);case ApiError_InvalidHandle() when invalidHandle != null:
return invalidHandle(_that);case ApiError_StalePayload() when stalePayload != null:
return stalePayload(_that);case ApiError_VaultLocked() when vaultLocked != null:
return vaultLocked(_that);case ApiError_ProviderUnavailable() when providerUnavailable != null:
return providerUnavailable(_that);case ApiError_OpenSuggestions() when openSuggestions != null:
return openSuggestions(_that);case ApiError_ImportRefused() when importRefused != null:
return importRefused(_that);case ApiError_BadSpan() when badSpan != null:
return badSpan(_that);case ApiError_UnknownToken() when unknownToken != null:
return unknownToken(_that);case ApiError_NothingToSend() when nothingToSend != null:
return nothingToSend(_that);case ApiError_PayloadRefused() when payloadRefused != null:
return payloadRefused(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ApiError_NotImplemented value)  notImplemented,required TResult Function( ApiError_InvalidSession value)  invalidSession,required TResult Function( ApiError_InvalidHandle value)  invalidHandle,required TResult Function( ApiError_StalePayload value)  stalePayload,required TResult Function( ApiError_VaultLocked value)  vaultLocked,required TResult Function( ApiError_ProviderUnavailable value)  providerUnavailable,required TResult Function( ApiError_OpenSuggestions value)  openSuggestions,required TResult Function( ApiError_ImportRefused value)  importRefused,required TResult Function( ApiError_BadSpan value)  badSpan,required TResult Function( ApiError_UnknownToken value)  unknownToken,required TResult Function( ApiError_NothingToSend value)  nothingToSend,required TResult Function( ApiError_PayloadRefused value)  payloadRefused,}){
final _that = this;
switch (_that) {
case ApiError_NotImplemented():
return notImplemented(_that);case ApiError_InvalidSession():
return invalidSession(_that);case ApiError_InvalidHandle():
return invalidHandle(_that);case ApiError_StalePayload():
return stalePayload(_that);case ApiError_VaultLocked():
return vaultLocked(_that);case ApiError_ProviderUnavailable():
return providerUnavailable(_that);case ApiError_OpenSuggestions():
return openSuggestions(_that);case ApiError_ImportRefused():
return importRefused(_that);case ApiError_BadSpan():
return badSpan(_that);case ApiError_UnknownToken():
return unknownToken(_that);case ApiError_NothingToSend():
return nothingToSend(_that);case ApiError_PayloadRefused():
return payloadRefused(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ApiError_NotImplemented value)?  notImplemented,TResult? Function( ApiError_InvalidSession value)?  invalidSession,TResult? Function( ApiError_InvalidHandle value)?  invalidHandle,TResult? Function( ApiError_StalePayload value)?  stalePayload,TResult? Function( ApiError_VaultLocked value)?  vaultLocked,TResult? Function( ApiError_ProviderUnavailable value)?  providerUnavailable,TResult? Function( ApiError_OpenSuggestions value)?  openSuggestions,TResult? Function( ApiError_ImportRefused value)?  importRefused,TResult? Function( ApiError_BadSpan value)?  badSpan,TResult? Function( ApiError_UnknownToken value)?  unknownToken,TResult? Function( ApiError_NothingToSend value)?  nothingToSend,TResult? Function( ApiError_PayloadRefused value)?  payloadRefused,}){
final _that = this;
switch (_that) {
case ApiError_NotImplemented() when notImplemented != null:
return notImplemented(_that);case ApiError_InvalidSession() when invalidSession != null:
return invalidSession(_that);case ApiError_InvalidHandle() when invalidHandle != null:
return invalidHandle(_that);case ApiError_StalePayload() when stalePayload != null:
return stalePayload(_that);case ApiError_VaultLocked() when vaultLocked != null:
return vaultLocked(_that);case ApiError_ProviderUnavailable() when providerUnavailable != null:
return providerUnavailable(_that);case ApiError_OpenSuggestions() when openSuggestions != null:
return openSuggestions(_that);case ApiError_ImportRefused() when importRefused != null:
return importRefused(_that);case ApiError_BadSpan() when badSpan != null:
return badSpan(_that);case ApiError_UnknownToken() when unknownToken != null:
return unknownToken(_that);case ApiError_NothingToSend() when nothingToSend != null:
return nothingToSend(_that);case ApiError_PayloadRefused() when payloadRefused != null:
return payloadRefused(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  notImplemented,TResult Function()?  invalidSession,TResult Function()?  invalidHandle,TResult Function( int expected,  int got)?  stalePayload,TResult Function()?  vaultLocked,TResult Function( String provider)?  providerUnavailable,TResult Function( int count)?  openSuggestions,TResult Function( String reason)?  importRefused,TResult Function( String reason)?  badSpan,TResult Function()?  unknownToken,TResult Function()?  nothingToSend,TResult Function( String reason)?  payloadRefused,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ApiError_NotImplemented() when notImplemented != null:
return notImplemented();case ApiError_InvalidSession() when invalidSession != null:
return invalidSession();case ApiError_InvalidHandle() when invalidHandle != null:
return invalidHandle();case ApiError_StalePayload() when stalePayload != null:
return stalePayload(_that.expected,_that.got);case ApiError_VaultLocked() when vaultLocked != null:
return vaultLocked();case ApiError_ProviderUnavailable() when providerUnavailable != null:
return providerUnavailable(_that.provider);case ApiError_OpenSuggestions() when openSuggestions != null:
return openSuggestions(_that.count);case ApiError_ImportRefused() when importRefused != null:
return importRefused(_that.reason);case ApiError_BadSpan() when badSpan != null:
return badSpan(_that.reason);case ApiError_UnknownToken() when unknownToken != null:
return unknownToken();case ApiError_NothingToSend() when nothingToSend != null:
return nothingToSend();case ApiError_PayloadRefused() when payloadRefused != null:
return payloadRefused(_that.reason);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  notImplemented,required TResult Function()  invalidSession,required TResult Function()  invalidHandle,required TResult Function( int expected,  int got)  stalePayload,required TResult Function()  vaultLocked,required TResult Function( String provider)  providerUnavailable,required TResult Function( int count)  openSuggestions,required TResult Function( String reason)  importRefused,required TResult Function( String reason)  badSpan,required TResult Function()  unknownToken,required TResult Function()  nothingToSend,required TResult Function( String reason)  payloadRefused,}) {final _that = this;
switch (_that) {
case ApiError_NotImplemented():
return notImplemented();case ApiError_InvalidSession():
return invalidSession();case ApiError_InvalidHandle():
return invalidHandle();case ApiError_StalePayload():
return stalePayload(_that.expected,_that.got);case ApiError_VaultLocked():
return vaultLocked();case ApiError_ProviderUnavailable():
return providerUnavailable(_that.provider);case ApiError_OpenSuggestions():
return openSuggestions(_that.count);case ApiError_ImportRefused():
return importRefused(_that.reason);case ApiError_BadSpan():
return badSpan(_that.reason);case ApiError_UnknownToken():
return unknownToken();case ApiError_NothingToSend():
return nothingToSend();case ApiError_PayloadRefused():
return payloadRefused(_that.reason);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  notImplemented,TResult? Function()?  invalidSession,TResult? Function()?  invalidHandle,TResult? Function( int expected,  int got)?  stalePayload,TResult? Function()?  vaultLocked,TResult? Function( String provider)?  providerUnavailable,TResult? Function( int count)?  openSuggestions,TResult? Function( String reason)?  importRefused,TResult? Function( String reason)?  badSpan,TResult? Function()?  unknownToken,TResult? Function()?  nothingToSend,TResult? Function( String reason)?  payloadRefused,}) {final _that = this;
switch (_that) {
case ApiError_NotImplemented() when notImplemented != null:
return notImplemented();case ApiError_InvalidSession() when invalidSession != null:
return invalidSession();case ApiError_InvalidHandle() when invalidHandle != null:
return invalidHandle();case ApiError_StalePayload() when stalePayload != null:
return stalePayload(_that.expected,_that.got);case ApiError_VaultLocked() when vaultLocked != null:
return vaultLocked();case ApiError_ProviderUnavailable() when providerUnavailable != null:
return providerUnavailable(_that.provider);case ApiError_OpenSuggestions() when openSuggestions != null:
return openSuggestions(_that.count);case ApiError_ImportRefused() when importRefused != null:
return importRefused(_that.reason);case ApiError_BadSpan() when badSpan != null:
return badSpan(_that.reason);case ApiError_UnknownToken() when unknownToken != null:
return unknownToken();case ApiError_NothingToSend() when nothingToSend != null:
return nothingToSend();case ApiError_PayloadRefused() when payloadRefused != null:
return payloadRefused(_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class ApiError_NotImplemented extends ApiError {
  const ApiError_NotImplemented(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_NotImplemented);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError.notImplemented()';
}


}




/// @nodoc


class ApiError_InvalidSession extends ApiError {
  const ApiError_InvalidSession(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_InvalidSession);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError.invalidSession()';
}


}




/// @nodoc


class ApiError_InvalidHandle extends ApiError {
  const ApiError_InvalidHandle(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_InvalidHandle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError.invalidHandle()';
}


}




/// @nodoc


class ApiError_StalePayload extends ApiError {
  const ApiError_StalePayload({required this.expected, required this.got}): super._();
  

 final  int expected;
 final  int got;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiError_StalePayloadCopyWith<ApiError_StalePayload> get copyWith => _$ApiError_StalePayloadCopyWithImpl<ApiError_StalePayload>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_StalePayload&&(identical(other.expected, expected) || other.expected == expected)&&(identical(other.got, got) || other.got == got));
}


@override
int get hashCode => Object.hash(runtimeType,expected,got);

@override
String toString() {
  return 'ApiError.stalePayload(expected: $expected, got: $got)';
}


}

/// @nodoc
abstract mixin class $ApiError_StalePayloadCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $ApiError_StalePayloadCopyWith(ApiError_StalePayload value, $Res Function(ApiError_StalePayload) _then) = _$ApiError_StalePayloadCopyWithImpl;
@useResult
$Res call({
 int expected, int got
});




}
/// @nodoc
class _$ApiError_StalePayloadCopyWithImpl<$Res>
    implements $ApiError_StalePayloadCopyWith<$Res> {
  _$ApiError_StalePayloadCopyWithImpl(this._self, this._then);

  final ApiError_StalePayload _self;
  final $Res Function(ApiError_StalePayload) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? expected = null,Object? got = null,}) {
  return _then(ApiError_StalePayload(
expected: null == expected ? _self.expected : expected // ignore: cast_nullable_to_non_nullable
as int,got: null == got ? _self.got : got // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ApiError_VaultLocked extends ApiError {
  const ApiError_VaultLocked(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_VaultLocked);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError.vaultLocked()';
}


}




/// @nodoc


class ApiError_ProviderUnavailable extends ApiError {
  const ApiError_ProviderUnavailable({required this.provider}): super._();
  

 final  String provider;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiError_ProviderUnavailableCopyWith<ApiError_ProviderUnavailable> get copyWith => _$ApiError_ProviderUnavailableCopyWithImpl<ApiError_ProviderUnavailable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_ProviderUnavailable&&(identical(other.provider, provider) || other.provider == provider));
}


@override
int get hashCode => Object.hash(runtimeType,provider);

@override
String toString() {
  return 'ApiError.providerUnavailable(provider: $provider)';
}


}

/// @nodoc
abstract mixin class $ApiError_ProviderUnavailableCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $ApiError_ProviderUnavailableCopyWith(ApiError_ProviderUnavailable value, $Res Function(ApiError_ProviderUnavailable) _then) = _$ApiError_ProviderUnavailableCopyWithImpl;
@useResult
$Res call({
 String provider
});




}
/// @nodoc
class _$ApiError_ProviderUnavailableCopyWithImpl<$Res>
    implements $ApiError_ProviderUnavailableCopyWith<$Res> {
  _$ApiError_ProviderUnavailableCopyWithImpl(this._self, this._then);

  final ApiError_ProviderUnavailable _self;
  final $Res Function(ApiError_ProviderUnavailable) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? provider = null,}) {
  return _then(ApiError_ProviderUnavailable(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ApiError_OpenSuggestions extends ApiError {
  const ApiError_OpenSuggestions({required this.count}): super._();
  

 final  int count;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiError_OpenSuggestionsCopyWith<ApiError_OpenSuggestions> get copyWith => _$ApiError_OpenSuggestionsCopyWithImpl<ApiError_OpenSuggestions>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_OpenSuggestions&&(identical(other.count, count) || other.count == count));
}


@override
int get hashCode => Object.hash(runtimeType,count);

@override
String toString() {
  return 'ApiError.openSuggestions(count: $count)';
}


}

/// @nodoc
abstract mixin class $ApiError_OpenSuggestionsCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $ApiError_OpenSuggestionsCopyWith(ApiError_OpenSuggestions value, $Res Function(ApiError_OpenSuggestions) _then) = _$ApiError_OpenSuggestionsCopyWithImpl;
@useResult
$Res call({
 int count
});




}
/// @nodoc
class _$ApiError_OpenSuggestionsCopyWithImpl<$Res>
    implements $ApiError_OpenSuggestionsCopyWith<$Res> {
  _$ApiError_OpenSuggestionsCopyWithImpl(this._self, this._then);

  final ApiError_OpenSuggestions _self;
  final $Res Function(ApiError_OpenSuggestions) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? count = null,}) {
  return _then(ApiError_OpenSuggestions(
count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ApiError_ImportRefused extends ApiError {
  const ApiError_ImportRefused({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiError_ImportRefusedCopyWith<ApiError_ImportRefused> get copyWith => _$ApiError_ImportRefusedCopyWithImpl<ApiError_ImportRefused>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_ImportRefused&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'ApiError.importRefused(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $ApiError_ImportRefusedCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $ApiError_ImportRefusedCopyWith(ApiError_ImportRefused value, $Res Function(ApiError_ImportRefused) _then) = _$ApiError_ImportRefusedCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$ApiError_ImportRefusedCopyWithImpl<$Res>
    implements $ApiError_ImportRefusedCopyWith<$Res> {
  _$ApiError_ImportRefusedCopyWithImpl(this._self, this._then);

  final ApiError_ImportRefused _self;
  final $Res Function(ApiError_ImportRefused) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(ApiError_ImportRefused(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ApiError_BadSpan extends ApiError {
  const ApiError_BadSpan({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiError_BadSpanCopyWith<ApiError_BadSpan> get copyWith => _$ApiError_BadSpanCopyWithImpl<ApiError_BadSpan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_BadSpan&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'ApiError.badSpan(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $ApiError_BadSpanCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $ApiError_BadSpanCopyWith(ApiError_BadSpan value, $Res Function(ApiError_BadSpan) _then) = _$ApiError_BadSpanCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$ApiError_BadSpanCopyWithImpl<$Res>
    implements $ApiError_BadSpanCopyWith<$Res> {
  _$ApiError_BadSpanCopyWithImpl(this._self, this._then);

  final ApiError_BadSpan _self;
  final $Res Function(ApiError_BadSpan) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(ApiError_BadSpan(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ApiError_UnknownToken extends ApiError {
  const ApiError_UnknownToken(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_UnknownToken);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError.unknownToken()';
}


}




/// @nodoc


class ApiError_NothingToSend extends ApiError {
  const ApiError_NothingToSend(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_NothingToSend);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApiError.nothingToSend()';
}


}




/// @nodoc


class ApiError_PayloadRefused extends ApiError {
  const ApiError_PayloadRefused({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiError_PayloadRefusedCopyWith<ApiError_PayloadRefused> get copyWith => _$ApiError_PayloadRefusedCopyWithImpl<ApiError_PayloadRefused>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiError_PayloadRefused&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'ApiError.payloadRefused(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $ApiError_PayloadRefusedCopyWith<$Res> implements $ApiErrorCopyWith<$Res> {
  factory $ApiError_PayloadRefusedCopyWith(ApiError_PayloadRefused value, $Res Function(ApiError_PayloadRefused) _then) = _$ApiError_PayloadRefusedCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$ApiError_PayloadRefusedCopyWithImpl<$Res>
    implements $ApiError_PayloadRefusedCopyWith<$Res> {
  _$ApiError_PayloadRefusedCopyWithImpl(this._self, this._then);

  final ApiError_PayloadRefused _self;
  final $Res Function(ApiError_PayloadRefused) _then;

/// Create a copy of ApiError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(ApiError_PayloadRefused(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ProtectOutcome {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProtectOutcome);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProtectOutcome()';
}


}

/// @nodoc
class $ProtectOutcomeCopyWith<$Res>  {
$ProtectOutcomeCopyWith(ProtectOutcome _, $Res Function(ProtectOutcome) __);
}


/// Adds pattern-matching-related methods to [ProtectOutcome].
extension ProtectOutcomePatterns on ProtectOutcome {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ProtectOutcome_Applied value)?  applied,TResult Function( ProtectOutcome_AlreadyProtected value)?  alreadyProtected,TResult Function( ProtectOutcome_BelongsToEntity value)?  belongsToEntity,TResult Function( ProtectOutcome_Snapped value)?  snapped,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ProtectOutcome_Applied() when applied != null:
return applied(_that);case ProtectOutcome_AlreadyProtected() when alreadyProtected != null:
return alreadyProtected(_that);case ProtectOutcome_BelongsToEntity() when belongsToEntity != null:
return belongsToEntity(_that);case ProtectOutcome_Snapped() when snapped != null:
return snapped(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ProtectOutcome_Applied value)  applied,required TResult Function( ProtectOutcome_AlreadyProtected value)  alreadyProtected,required TResult Function( ProtectOutcome_BelongsToEntity value)  belongsToEntity,required TResult Function( ProtectOutcome_Snapped value)  snapped,}){
final _that = this;
switch (_that) {
case ProtectOutcome_Applied():
return applied(_that);case ProtectOutcome_AlreadyProtected():
return alreadyProtected(_that);case ProtectOutcome_BelongsToEntity():
return belongsToEntity(_that);case ProtectOutcome_Snapped():
return snapped(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ProtectOutcome_Applied value)?  applied,TResult? Function( ProtectOutcome_AlreadyProtected value)?  alreadyProtected,TResult? Function( ProtectOutcome_BelongsToEntity value)?  belongsToEntity,TResult? Function( ProtectOutcome_Snapped value)?  snapped,}){
final _that = this;
switch (_that) {
case ProtectOutcome_Applied() when applied != null:
return applied(_that);case ProtectOutcome_AlreadyProtected() when alreadyProtected != null:
return alreadyProtected(_that);case ProtectOutcome_BelongsToEntity() when belongsToEntity != null:
return belongsToEntity(_that);case ProtectOutcome_Snapped() when snapped != null:
return snapped(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String token,  int places)?  applied,TResult Function( String token,  Source source,  String sourceDetail)?  alreadyProtected,TResult Function( String entity,  String token)?  belongsToEntity,TResult Function( List<Span> spans)?  snapped,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ProtectOutcome_Applied() when applied != null:
return applied(_that.token,_that.places);case ProtectOutcome_AlreadyProtected() when alreadyProtected != null:
return alreadyProtected(_that.token,_that.source,_that.sourceDetail);case ProtectOutcome_BelongsToEntity() when belongsToEntity != null:
return belongsToEntity(_that.entity,_that.token);case ProtectOutcome_Snapped() when snapped != null:
return snapped(_that.spans);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String token,  int places)  applied,required TResult Function( String token,  Source source,  String sourceDetail)  alreadyProtected,required TResult Function( String entity,  String token)  belongsToEntity,required TResult Function( List<Span> spans)  snapped,}) {final _that = this;
switch (_that) {
case ProtectOutcome_Applied():
return applied(_that.token,_that.places);case ProtectOutcome_AlreadyProtected():
return alreadyProtected(_that.token,_that.source,_that.sourceDetail);case ProtectOutcome_BelongsToEntity():
return belongsToEntity(_that.entity,_that.token);case ProtectOutcome_Snapped():
return snapped(_that.spans);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String token,  int places)?  applied,TResult? Function( String token,  Source source,  String sourceDetail)?  alreadyProtected,TResult? Function( String entity,  String token)?  belongsToEntity,TResult? Function( List<Span> spans)?  snapped,}) {final _that = this;
switch (_that) {
case ProtectOutcome_Applied() when applied != null:
return applied(_that.token,_that.places);case ProtectOutcome_AlreadyProtected() when alreadyProtected != null:
return alreadyProtected(_that.token,_that.source,_that.sourceDetail);case ProtectOutcome_BelongsToEntity() when belongsToEntity != null:
return belongsToEntity(_that.entity,_that.token);case ProtectOutcome_Snapped() when snapped != null:
return snapped(_that.spans);case _:
  return null;

}
}

}

/// @nodoc


class ProtectOutcome_Applied extends ProtectOutcome {
  const ProtectOutcome_Applied({required this.token, required this.places}): super._();
  

 final  String token;
 final  int places;

/// Create a copy of ProtectOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProtectOutcome_AppliedCopyWith<ProtectOutcome_Applied> get copyWith => _$ProtectOutcome_AppliedCopyWithImpl<ProtectOutcome_Applied>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProtectOutcome_Applied&&(identical(other.token, token) || other.token == token)&&(identical(other.places, places) || other.places == places));
}


@override
int get hashCode => Object.hash(runtimeType,token,places);

@override
String toString() {
  return 'ProtectOutcome.applied(token: $token, places: $places)';
}


}

/// @nodoc
abstract mixin class $ProtectOutcome_AppliedCopyWith<$Res> implements $ProtectOutcomeCopyWith<$Res> {
  factory $ProtectOutcome_AppliedCopyWith(ProtectOutcome_Applied value, $Res Function(ProtectOutcome_Applied) _then) = _$ProtectOutcome_AppliedCopyWithImpl;
@useResult
$Res call({
 String token, int places
});




}
/// @nodoc
class _$ProtectOutcome_AppliedCopyWithImpl<$Res>
    implements $ProtectOutcome_AppliedCopyWith<$Res> {
  _$ProtectOutcome_AppliedCopyWithImpl(this._self, this._then);

  final ProtectOutcome_Applied _self;
  final $Res Function(ProtectOutcome_Applied) _then;

/// Create a copy of ProtectOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? places = null,}) {
  return _then(ProtectOutcome_Applied(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,places: null == places ? _self.places : places // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ProtectOutcome_AlreadyProtected extends ProtectOutcome {
  const ProtectOutcome_AlreadyProtected({required this.token, required this.source, required this.sourceDetail}): super._();
  

 final  String token;
 final  Source source;
 final  String sourceDetail;

/// Create a copy of ProtectOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProtectOutcome_AlreadyProtectedCopyWith<ProtectOutcome_AlreadyProtected> get copyWith => _$ProtectOutcome_AlreadyProtectedCopyWithImpl<ProtectOutcome_AlreadyProtected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProtectOutcome_AlreadyProtected&&(identical(other.token, token) || other.token == token)&&(identical(other.source, source) || other.source == source)&&(identical(other.sourceDetail, sourceDetail) || other.sourceDetail == sourceDetail));
}


@override
int get hashCode => Object.hash(runtimeType,token,source,sourceDetail);

@override
String toString() {
  return 'ProtectOutcome.alreadyProtected(token: $token, source: $source, sourceDetail: $sourceDetail)';
}


}

/// @nodoc
abstract mixin class $ProtectOutcome_AlreadyProtectedCopyWith<$Res> implements $ProtectOutcomeCopyWith<$Res> {
  factory $ProtectOutcome_AlreadyProtectedCopyWith(ProtectOutcome_AlreadyProtected value, $Res Function(ProtectOutcome_AlreadyProtected) _then) = _$ProtectOutcome_AlreadyProtectedCopyWithImpl;
@useResult
$Res call({
 String token, Source source, String sourceDetail
});




}
/// @nodoc
class _$ProtectOutcome_AlreadyProtectedCopyWithImpl<$Res>
    implements $ProtectOutcome_AlreadyProtectedCopyWith<$Res> {
  _$ProtectOutcome_AlreadyProtectedCopyWithImpl(this._self, this._then);

  final ProtectOutcome_AlreadyProtected _self;
  final $Res Function(ProtectOutcome_AlreadyProtected) _then;

/// Create a copy of ProtectOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? source = null,Object? sourceDetail = null,}) {
  return _then(ProtectOutcome_AlreadyProtected(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as Source,sourceDetail: null == sourceDetail ? _self.sourceDetail : sourceDetail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ProtectOutcome_BelongsToEntity extends ProtectOutcome {
  const ProtectOutcome_BelongsToEntity({required this.entity, required this.token}): super._();
  

 final  String entity;
 final  String token;

/// Create a copy of ProtectOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProtectOutcome_BelongsToEntityCopyWith<ProtectOutcome_BelongsToEntity> get copyWith => _$ProtectOutcome_BelongsToEntityCopyWithImpl<ProtectOutcome_BelongsToEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProtectOutcome_BelongsToEntity&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.token, token) || other.token == token));
}


@override
int get hashCode => Object.hash(runtimeType,entity,token);

@override
String toString() {
  return 'ProtectOutcome.belongsToEntity(entity: $entity, token: $token)';
}


}

/// @nodoc
abstract mixin class $ProtectOutcome_BelongsToEntityCopyWith<$Res> implements $ProtectOutcomeCopyWith<$Res> {
  factory $ProtectOutcome_BelongsToEntityCopyWith(ProtectOutcome_BelongsToEntity value, $Res Function(ProtectOutcome_BelongsToEntity) _then) = _$ProtectOutcome_BelongsToEntityCopyWithImpl;
@useResult
$Res call({
 String entity, String token
});




}
/// @nodoc
class _$ProtectOutcome_BelongsToEntityCopyWithImpl<$Res>
    implements $ProtectOutcome_BelongsToEntityCopyWith<$Res> {
  _$ProtectOutcome_BelongsToEntityCopyWithImpl(this._self, this._then);

  final ProtectOutcome_BelongsToEntity _self;
  final $Res Function(ProtectOutcome_BelongsToEntity) _then;

/// Create a copy of ProtectOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? entity = null,Object? token = null,}) {
  return _then(ProtectOutcome_BelongsToEntity(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ProtectOutcome_Snapped extends ProtectOutcome {
  const ProtectOutcome_Snapped({required final  List<Span> spans}): _spans = spans,super._();
  

 final  List<Span> _spans;
 List<Span> get spans {
  if (_spans is EqualUnmodifiableListView) return _spans;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_spans);
}


/// Create a copy of ProtectOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProtectOutcome_SnappedCopyWith<ProtectOutcome_Snapped> get copyWith => _$ProtectOutcome_SnappedCopyWithImpl<ProtectOutcome_Snapped>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProtectOutcome_Snapped&&const DeepCollectionEquality().equals(other._spans, _spans));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_spans));

@override
String toString() {
  return 'ProtectOutcome.snapped(spans: $spans)';
}


}

/// @nodoc
abstract mixin class $ProtectOutcome_SnappedCopyWith<$Res> implements $ProtectOutcomeCopyWith<$Res> {
  factory $ProtectOutcome_SnappedCopyWith(ProtectOutcome_Snapped value, $Res Function(ProtectOutcome_Snapped) _then) = _$ProtectOutcome_SnappedCopyWithImpl;
@useResult
$Res call({
 List<Span> spans
});




}
/// @nodoc
class _$ProtectOutcome_SnappedCopyWithImpl<$Res>
    implements $ProtectOutcome_SnappedCopyWith<$Res> {
  _$ProtectOutcome_SnappedCopyWithImpl(this._self, this._then);

  final ProtectOutcome_Snapped _self;
  final $Res Function(ProtectOutcome_Snapped) _then;

/// Create a copy of ProtectOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? spans = null,}) {
  return _then(ProtectOutcome_Snapped(
spans: null == spans ? _self._spans : spans // ignore: cast_nullable_to_non_nullable
as List<Span>,
  ));
}


}

/// @nodoc
mixin _$UndoOutcome {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UndoOutcome);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UndoOutcome()';
}


}

/// @nodoc
class $UndoOutcomeCopyWith<$Res>  {
$UndoOutcomeCopyWith(UndoOutcome _, $Res Function(UndoOutcome) __);
}


/// Adds pattern-matching-related methods to [UndoOutcome].
extension UndoOutcomePatterns on UndoOutcome {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UndoOutcome_NothingToUndo value)?  nothingToUndo,TResult Function( UndoOutcome_Undone value)?  undone,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UndoOutcome_NothingToUndo() when nothingToUndo != null:
return nothingToUndo(_that);case UndoOutcome_Undone() when undone != null:
return undone(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UndoOutcome_NothingToUndo value)  nothingToUndo,required TResult Function( UndoOutcome_Undone value)  undone,}){
final _that = this;
switch (_that) {
case UndoOutcome_NothingToUndo():
return nothingToUndo(_that);case UndoOutcome_Undone():
return undone(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UndoOutcome_NothingToUndo value)?  nothingToUndo,TResult? Function( UndoOutcome_Undone value)?  undone,}){
final _that = this;
switch (_that) {
case UndoOutcome_NothingToUndo() when nothingToUndo != null:
return nothingToUndo(_that);case UndoOutcome_Undone() when undone != null:
return undone(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  nothingToUndo,TResult Function( String token,  int places,  String? createdEntity)?  undone,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UndoOutcome_NothingToUndo() when nothingToUndo != null:
return nothingToUndo();case UndoOutcome_Undone() when undone != null:
return undone(_that.token,_that.places,_that.createdEntity);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  nothingToUndo,required TResult Function( String token,  int places,  String? createdEntity)  undone,}) {final _that = this;
switch (_that) {
case UndoOutcome_NothingToUndo():
return nothingToUndo();case UndoOutcome_Undone():
return undone(_that.token,_that.places,_that.createdEntity);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  nothingToUndo,TResult? Function( String token,  int places,  String? createdEntity)?  undone,}) {final _that = this;
switch (_that) {
case UndoOutcome_NothingToUndo() when nothingToUndo != null:
return nothingToUndo();case UndoOutcome_Undone() when undone != null:
return undone(_that.token,_that.places,_that.createdEntity);case _:
  return null;

}
}

}

/// @nodoc


class UndoOutcome_NothingToUndo extends UndoOutcome {
  const UndoOutcome_NothingToUndo(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UndoOutcome_NothingToUndo);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UndoOutcome.nothingToUndo()';
}


}




/// @nodoc


class UndoOutcome_Undone extends UndoOutcome {
  const UndoOutcome_Undone({required this.token, required this.places, this.createdEntity}): super._();
  

 final  String token;
 final  int places;
 final  String? createdEntity;

/// Create a copy of UndoOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UndoOutcome_UndoneCopyWith<UndoOutcome_Undone> get copyWith => _$UndoOutcome_UndoneCopyWithImpl<UndoOutcome_Undone>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UndoOutcome_Undone&&(identical(other.token, token) || other.token == token)&&(identical(other.places, places) || other.places == places)&&(identical(other.createdEntity, createdEntity) || other.createdEntity == createdEntity));
}


@override
int get hashCode => Object.hash(runtimeType,token,places,createdEntity);

@override
String toString() {
  return 'UndoOutcome.undone(token: $token, places: $places, createdEntity: $createdEntity)';
}


}

/// @nodoc
abstract mixin class $UndoOutcome_UndoneCopyWith<$Res> implements $UndoOutcomeCopyWith<$Res> {
  factory $UndoOutcome_UndoneCopyWith(UndoOutcome_Undone value, $Res Function(UndoOutcome_Undone) _then) = _$UndoOutcome_UndoneCopyWithImpl;
@useResult
$Res call({
 String token, int places, String? createdEntity
});




}
/// @nodoc
class _$UndoOutcome_UndoneCopyWithImpl<$Res>
    implements $UndoOutcome_UndoneCopyWith<$Res> {
  _$UndoOutcome_UndoneCopyWithImpl(this._self, this._then);

  final UndoOutcome_Undone _self;
  final $Res Function(UndoOutcome_Undone) _then;

/// Create a copy of UndoOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? places = null,Object? createdEntity = freezed,}) {
  return _then(UndoOutcome_Undone(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,places: null == places ? _self.places : places // ignore: cast_nullable_to_non_nullable
as int,createdEntity: freezed == createdEntity ? _self.createdEntity : createdEntity // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VaultUnlockOutcome {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VaultUnlockOutcome);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'VaultUnlockOutcome()';
}


}

/// @nodoc
class $VaultUnlockOutcomeCopyWith<$Res>  {
$VaultUnlockOutcomeCopyWith(VaultUnlockOutcome _, $Res Function(VaultUnlockOutcome) __);
}


/// Adds pattern-matching-related methods to [VaultUnlockOutcome].
extension VaultUnlockOutcomePatterns on VaultUnlockOutcome {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( VaultUnlockOutcome_Unlocked value)?  unlocked,TResult Function( VaultUnlockOutcome_WrongPassphrase value)?  wrongPassphrase,required TResult orElse(),}){
final _that = this;
switch (_that) {
case VaultUnlockOutcome_Unlocked() when unlocked != null:
return unlocked(_that);case VaultUnlockOutcome_WrongPassphrase() when wrongPassphrase != null:
return wrongPassphrase(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( VaultUnlockOutcome_Unlocked value)  unlocked,required TResult Function( VaultUnlockOutcome_WrongPassphrase value)  wrongPassphrase,}){
final _that = this;
switch (_that) {
case VaultUnlockOutcome_Unlocked():
return unlocked(_that);case VaultUnlockOutcome_WrongPassphrase():
return wrongPassphrase(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( VaultUnlockOutcome_Unlocked value)?  unlocked,TResult? Function( VaultUnlockOutcome_WrongPassphrase value)?  wrongPassphrase,}){
final _that = this;
switch (_that) {
case VaultUnlockOutcome_Unlocked() when unlocked != null:
return unlocked(_that);case VaultUnlockOutcome_WrongPassphrase() when wrongPassphrase != null:
return wrongPassphrase(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int identities,  int values)?  unlocked,TResult Function( int attemptsLeft)?  wrongPassphrase,required TResult orElse(),}) {final _that = this;
switch (_that) {
case VaultUnlockOutcome_Unlocked() when unlocked != null:
return unlocked(_that.identities,_that.values);case VaultUnlockOutcome_WrongPassphrase() when wrongPassphrase != null:
return wrongPassphrase(_that.attemptsLeft);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int identities,  int values)  unlocked,required TResult Function( int attemptsLeft)  wrongPassphrase,}) {final _that = this;
switch (_that) {
case VaultUnlockOutcome_Unlocked():
return unlocked(_that.identities,_that.values);case VaultUnlockOutcome_WrongPassphrase():
return wrongPassphrase(_that.attemptsLeft);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int identities,  int values)?  unlocked,TResult? Function( int attemptsLeft)?  wrongPassphrase,}) {final _that = this;
switch (_that) {
case VaultUnlockOutcome_Unlocked() when unlocked != null:
return unlocked(_that.identities,_that.values);case VaultUnlockOutcome_WrongPassphrase() when wrongPassphrase != null:
return wrongPassphrase(_that.attemptsLeft);case _:
  return null;

}
}

}

/// @nodoc


class VaultUnlockOutcome_Unlocked extends VaultUnlockOutcome {
  const VaultUnlockOutcome_Unlocked({required this.identities, required this.values}): super._();
  

 final  int identities;
 final  int values;

/// Create a copy of VaultUnlockOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VaultUnlockOutcome_UnlockedCopyWith<VaultUnlockOutcome_Unlocked> get copyWith => _$VaultUnlockOutcome_UnlockedCopyWithImpl<VaultUnlockOutcome_Unlocked>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VaultUnlockOutcome_Unlocked&&(identical(other.identities, identities) || other.identities == identities)&&(identical(other.values, values) || other.values == values));
}


@override
int get hashCode => Object.hash(runtimeType,identities,values);

@override
String toString() {
  return 'VaultUnlockOutcome.unlocked(identities: $identities, values: $values)';
}


}

/// @nodoc
abstract mixin class $VaultUnlockOutcome_UnlockedCopyWith<$Res> implements $VaultUnlockOutcomeCopyWith<$Res> {
  factory $VaultUnlockOutcome_UnlockedCopyWith(VaultUnlockOutcome_Unlocked value, $Res Function(VaultUnlockOutcome_Unlocked) _then) = _$VaultUnlockOutcome_UnlockedCopyWithImpl;
@useResult
$Res call({
 int identities, int values
});




}
/// @nodoc
class _$VaultUnlockOutcome_UnlockedCopyWithImpl<$Res>
    implements $VaultUnlockOutcome_UnlockedCopyWith<$Res> {
  _$VaultUnlockOutcome_UnlockedCopyWithImpl(this._self, this._then);

  final VaultUnlockOutcome_Unlocked _self;
  final $Res Function(VaultUnlockOutcome_Unlocked) _then;

/// Create a copy of VaultUnlockOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identities = null,Object? values = null,}) {
  return _then(VaultUnlockOutcome_Unlocked(
identities: null == identities ? _self.identities : identities // ignore: cast_nullable_to_non_nullable
as int,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class VaultUnlockOutcome_WrongPassphrase extends VaultUnlockOutcome {
  const VaultUnlockOutcome_WrongPassphrase({required this.attemptsLeft}): super._();
  

 final  int attemptsLeft;

/// Create a copy of VaultUnlockOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VaultUnlockOutcome_WrongPassphraseCopyWith<VaultUnlockOutcome_WrongPassphrase> get copyWith => _$VaultUnlockOutcome_WrongPassphraseCopyWithImpl<VaultUnlockOutcome_WrongPassphrase>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VaultUnlockOutcome_WrongPassphrase&&(identical(other.attemptsLeft, attemptsLeft) || other.attemptsLeft == attemptsLeft));
}


@override
int get hashCode => Object.hash(runtimeType,attemptsLeft);

@override
String toString() {
  return 'VaultUnlockOutcome.wrongPassphrase(attemptsLeft: $attemptsLeft)';
}


}

/// @nodoc
abstract mixin class $VaultUnlockOutcome_WrongPassphraseCopyWith<$Res> implements $VaultUnlockOutcomeCopyWith<$Res> {
  factory $VaultUnlockOutcome_WrongPassphraseCopyWith(VaultUnlockOutcome_WrongPassphrase value, $Res Function(VaultUnlockOutcome_WrongPassphrase) _then) = _$VaultUnlockOutcome_WrongPassphraseCopyWithImpl;
@useResult
$Res call({
 int attemptsLeft
});




}
/// @nodoc
class _$VaultUnlockOutcome_WrongPassphraseCopyWithImpl<$Res>
    implements $VaultUnlockOutcome_WrongPassphraseCopyWith<$Res> {
  _$VaultUnlockOutcome_WrongPassphraseCopyWithImpl(this._self, this._then);

  final VaultUnlockOutcome_WrongPassphrase _self;
  final $Res Function(VaultUnlockOutcome_WrongPassphrase) _then;

/// Create a copy of VaultUnlockOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? attemptsLeft = null,}) {
  return _then(VaultUnlockOutcome_WrongPassphrase(
attemptsLeft: null == attemptsLeft ? _self.attemptsLeft : attemptsLeft // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
