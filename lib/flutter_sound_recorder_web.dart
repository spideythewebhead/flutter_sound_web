/*
 * Copyright 2018, 2019, 2020 Dooboolab.
 *
 * This file is part of Flutter-Sound.
 *
 * Flutter-Sound is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3 (LGPL-V3), as published by
 * the Free Software Foundation.
 *
 * Flutter-Sound is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Flutter-Sound.  If not, see <https://www.gnu.org/licenses/>.
 */

@JS()
library flutter_sound;

import 'dart:async';
//import 'dart:html' as html;

//import 'package:meta/meta.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_platform_interface.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart' show Level;
//import 'dart:web_audio';
import 'dart:html';
//import 'package:audio_session/audio_session.dart';
import 'package:js/js.dart';
import 'dart:html' as html;
import 'dart:web_audio';
//import 'package:web/web.dart';
//========================================  JS  ===============================================================

@JS('newRecorderInstance')
external FlutterSoundRecorder newRecorderInstance(
    FlutterSoundRecorderCallback callBack, List<Function> callbackTable);

@JS('FlutterSoundRecorder')
class FlutterSoundRecorder {
  @JS('newInstance')
  external static FlutterSoundRecorder newInstance(
      FlutterSoundRecorderCallback callBack, List<Function> callbackTable);

  @JS('initializeFlautoRecorder')
  external void initializeFlautoRecorder();

  @JS('releaseFlautoRecorder')
  external void releaseFlautoRecorder();

  @JS('setAudioFocus')
  external void setAudioFocus(
      int focus, int category, int mode, int? audioFlags, int device);

  @JS('isEncoderSupported')
  external bool isEncoderSupported(int codec);

  @JS('setSubscriptionDuration')
  external void setSubscriptionDuration(int duration);

  @JS('startRecorder')
  external void startRecorder(
      String? path,
      int? sampleRate,
      int? numChannels,
      int? bitRate,
      int? bufferSize,
      bool? enableVoiceProcessing,
      int codec,
      bool? toStream,
      int audioSource);

  @JS('stopRecorder')
  external void stopRecorder();

  @JS('pauseRecorder')
  external void pauseRecorder();

  @JS('resumeRecorder')
  external void resumeRecorder();

  @JS('getRecordURL')
  external String getRecordURL(
    String path,
  );

  @JS('deleteRecord')
  external bool deleteRecord(
    String path,
  );
}

List<Function> callbackTable = [
  allowInterop(
      (FlutterSoundRecorderCallback cb, int duration, double dbPeakLevel) {
    cb.updateRecorderProgress(duration: duration, dbPeakLevel: dbPeakLevel);
  }),
  allowInterop((FlutterSoundRecorderCallback cb, {Uint8List? data}) {
    cb.recordingData(data: data);
  }),
  allowInterop((FlutterSoundRecorderCallback cb, int state, bool success) {
    cb.startRecorderCompleted(state, success);
  }),
  allowInterop((FlutterSoundRecorderCallback cb, int state, bool success) {
    cb.pauseRecorderCompleted(state, success);
  }),
  allowInterop((FlutterSoundRecorderCallback cb, int state, bool success) {
    cb.resumeRecorderCompleted(state, success);
  }),
  allowInterop(
      (FlutterSoundRecorderCallback cb, int state, bool success, String url) {
    cb.stopRecorderCompleted(state, success, url);
  }),
  allowInterop((FlutterSoundRecorderCallback cb, int state, bool success) {
    cb.openRecorderCompleted(state, success);
  }),
  allowInterop((FlutterSoundRecorderCallback cb, int state, bool success) {
    cb.closeRecorderCompleted(state, success);
  }),
  allowInterop((FlutterSoundRecorderCallback cb, int level, String msg) {
    cb.log(Level.values[level], msg);
  }),
];

//============================================================================================================================

/// The web implementation of [FlutterSoundRecorderPlatform].
///
/// This class implements the `package:FlutterSoundPlayerPlatform` functionality for the web.
class FlutterSoundRecorderWeb
    extends FlutterSoundRecorderPlatform //implements FlutterSoundRecorderCallback
{
  /// Registers this class as the default instance of [FlutterSoundRecorderPlatform].
  static void registerWith(Registrar registrar) {
    FlutterSoundRecorderPlatform.instance = FlutterSoundRecorderWeb();
  }

  List<FlutterSoundRecorder?> _slots = [];
  FlutterSoundRecorder? getWebSession(FlutterSoundRecorderCallback callback) {
    return _slots[findSession(callback)];
  }

  AudioContext? audioCtx;
  StreamSubscription<Event>? sub;
  MediaStreamAudioSourceNode? source;
  ScriptProcessorNode? audioProcessor;

//================================================================================================================

  @override
  int getSampleRate(
    FlutterSoundRecorderCallback callback,
  ) {
    num sampleRate = audioCtx!.sampleRate!;
    return sampleRate.floor();
  }

  @override
  Future<void>? resetPlugin(
    FlutterSoundRecorderCallback callback,
  ) async {
    callback.log(Level.debug, '---> resetPlugin');
    for (int i = 0; i < _slots.length; ++i) {
      callback.log(Level.debug, "Releasing slot #$i");
      _slots[i]!.releaseFlautoRecorder();
    }
    _slots = [];
    callback.log(Level.debug, '<--- resetPlugin');
    return null;
  }

  @override
  Future<void> openRecorder(
    FlutterSoundRecorderCallback callback, {
    required Level logLevel,
  }) async {
    int slotno = findSession(callback);
    if (slotno < _slots.length) {
      assert(_slots[slotno] == null);
      _slots[slotno] = newRecorderInstance(callback, callbackTable);
    } else {
      assert(slotno == _slots.length);
      _slots.add(newRecorderInstance(callback, callbackTable));
    }
    audioCtx = AudioContext();

    getWebSession(callback)!.initializeFlautoRecorder();
  }

  @override
  Future<void> closeRecorder(
    FlutterSoundRecorderCallback callback,
  ) async {
    if (audioCtx != null) {
      audioCtx!.close();
      audioCtx = null;
    }
    int slotno = findSession(callback);
    _slots[slotno]!.releaseFlautoRecorder();
    _slots[slotno] = null;
  }

  @override
  Future<bool> isEncoderSupported(
    FlutterSoundRecorderCallback callback, {
    required Codec codec,
  }) async {
    if ((codec == Codec.pcm16) || (codec == Codec.pcmFloat32)) {
      return true;
    }
    return getWebSession(callback)!.isEncoderSupported(codec.index);
  }

  @override
  Future<void> setSubscriptionDuration(
    FlutterSoundRecorderCallback callback, {
    Duration? duration,
  }) async {
    getWebSession(callback)!.setSubscriptionDuration(duration!.inMilliseconds);
  }

  @override
  Future<void> startRecorder(
    FlutterSoundRecorderCallback callback, {
    String? path,
    int? sampleRate,
    int numChannels = 1,
    int? bitRate,
    int bufferSize = 8192,
    bool enableVoiceProcessing = false,
    Codec? codec,
    StreamSink<Uint8List>? toStream,
    StreamSink<List<Float32List>>? toStreamFloat32,
    StreamSink<List<Int16List>>? toStreamInt16,
    AudioSource? audioSource,
  }) async {
    if (toStream != null || toStreamFloat32 != null || toStreamInt16 != null) {
      if (toStream != null) {
        numChannels = 1;
      }
      callback.log(Level.debug, 'Start Recorder to Stream');
      AudioDestinationNode dest = audioCtx!.destination!;
      final html.MediaStream stream = await html.window.navigator.mediaDevices!
          .getUserMedia({'video': false, 'audio': true});
      source = audioCtx!.createMediaStreamSource(stream);
      audioProcessor =
          audioCtx!.createScriptProcessor(bufferSize, numChannels, 1);
      Stream<AudioProcessingEvent> audioStream = audioProcessor!.onAudioProcess;
      sub = audioStream.listen(
        (event) {
          List<Int16List> bi = [];
          List<Float32List> bf = [];
          for (int channel = 0; channel < numChannels; ++channel) {
            Float32List buf = event!.inputBuffer!.getChannelData(channel);
            int ln = buf.length;
            if (codec ==
                Codec
                    .pcmFloat32) // Actually, we do not handle the case where toStream is specified. This can be done if necessary
            {
              assert(toStreamFloat32 != null);
              bf.add(buf);
            } else if (codec == Codec.pcm16 && toStreamInt16 != null) {
              Int16List bufi = Int16List(ln);
              for (int i = 0; i < ln; ++i) {
                bufi[i] = (buf[i] * 32768).floor();
              }
              bi.add(bufi);
              //toStreamInt16.add(bufi);
            } else if (codec == Codec.pcm16 && toStream != null) {
              Uint8List bufu = Uint8List(ln * 2);
              for (int i = 0; i < ln; ++i) {
                int x = (buf[i] * 32768).floor();
                bufu[2 * i + 1] = x >> 8;
                bufu[2 * i] = x & 0xff;
              }
              toStream.add(bufu);
            }
          }
          if (codec ==
              Codec
                  .pcmFloat32) // Actually, we do not handle the case where toStream is specified. This can be done if necessary
          {
            toStreamFloat32!.add(bf);
          } else if (codec == Codec.pcm16 && toStreamInt16 != null) {
            toStreamInt16.add(bi);
          }
        },
      );
      //sub = onAudioProcess(audioProcessor!).listen ((Event event) {
      //Float32List datain = event.inputBuffer!.getChannelData(0);

      //StreamSubscription<Event> sub = audioStream!.listen((event) {
      //sub = onAudioProcess(audioProcessor!).listen ((Event event) {
      //Float32List datain = event.inputBuffer!.getChannelData(0);
      //Float32List dataout = event.outputBuffer!.getChannelData(0);
      callback.log(Level.debug, 'audio event ');

      //audioProcessor.addEventListener('audioprocess', (AudioProcessingEvent event)
      //{
      //  Float32List data = event.inputBuffer!.getChannelData(0);
      //  callback.log(Level.debug, 'audio event ');
      //});
      //source.connectNode(audioProcessor);
      //audioProcessor.connect(audioCtx.destination);
      //audioStarted = true;
//      AudioWorkletNode worketNode = AudioWorkletNode(audioCtx, 'flutter_sound_worklet');
//      worketNode.addEventListener('audioprocess', (Event event)
//      {
      //Float32List data = event.inputBuffer!.getChannelData(0);
//        callback.log(Level.debug, 'audio event ');
//      });

      source!.connectNode(audioProcessor!);
      audioProcessor!.connectNode(dest); // Why is it necessary ?
      callback.startRecorderCompleted(RecorderState.isRecording.index, true);
    } else {
      assert(codec != Codec.pcmFloat32 && codec != Codec.pcm16);
      getWebSession(callback)!.startRecorder(
        path,
        sampleRate,
        numChannels,
        bitRate,
        bufferSize,
        enableVoiceProcessing,
        codec!.index,
        toStream != null,
        audioSource!.index,
      );
    }
  }

  @override
  Future<void> stopRecorder(
    FlutterSoundRecorderCallback callback,
  ) async {
    if (sub != null) {
      sub!.cancel();
      sub = null;
    }
    if (source != null) {
      source!.disconnect();
      source = null;
    }
    if (audioProcessor != null) {
      audioProcessor!.disconnect();
      audioProcessor = null;
    }
    //audioCtx!.close(); // Not sure!
    FlutterSoundRecorder? session = getWebSession(callback);
    if (session != null)
      session.stopRecorder();
    else
      callback.log(Level.debug, 'Recorder already stopped');
  }

  @override
  Future<void> pauseRecorder(
    FlutterSoundRecorderCallback callback,
  ) async {
    if (sub != null) {
      audioCtx!.suspend();
    } else {
      getWebSession(callback)!.pauseRecorder();
    }
  }

  @override
  Future<void> resumeRecorder(
    FlutterSoundRecorderCallback callback,
  ) async {
    if (sub != null) {
      audioCtx!.resume();
    } else {
      getWebSession(callback)!.resumeRecorder();
    }
  }

  @override
  Future<String> getRecordURL(
      FlutterSoundRecorderCallback callback, String path) async {
    return getWebSession(callback)!.getRecordURL(path);
  }

  @override
  Future<bool> deleteRecord(
      FlutterSoundRecorderCallback callback, String path) async {
    return getWebSession(callback)!.deleteRecord(path);
  }
}
