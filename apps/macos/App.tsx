import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  AppState,
  Button,
  Image,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { cloudFiles, type CloudFile } from './src/cloudFiles';

type Editor = { name: string; text: string; create: boolean };

export default function App() {
  return (
    <View style={styles.screen}>
      <FilesScreen />
    </View>
  );
}

function FilesScreen() {
  const [files, setFiles] = useState<CloudFile[]>([]);
  const [connected, setConnected] = useState(false);
  const [busy, setBusy] = useState(false);
  const inFlight = useRef(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [editor, setEditor] = useState<Editor | null>(null);
  const [preview, setPreview] = useState<{ name: string; uri: string } | null>(
    null,
  );

  const run = useCallback(async (action: () => Promise<void>) => {
    if (inFlight.current) {
      return;
    }
    inFlight.current = true;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      await action();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  }, []);

  const reload = useCallback(async () => {
    try {
      const state = await cloudFiles.getState();
      if (!state.available) {
        throw new Error(
          'iCloud Drive를 사용할 수 없습니다. Mac 시스템 설정을 확인하세요.',
        );
      }
      const current = await cloudFiles.listFiles();
      setConnected(true);
      setFiles(current);
    } catch (cause) {
      setConnected(false);
      setFiles([]);
      throw cause;
    }
  }, []);

  useEffect(() => {
    run(reload);
    const subscription = AppState.addEventListener('change', state => {
      if (state === 'active') {
        run(reload);
      }
    });
    return () => subscription.remove();
  }, [reload, run]);

  const save = () => {
    if (!editor) {
      return;
    }
    const trimmed = editor.name.trim();
    const name = trimmed.toLowerCase().endsWith('.md')
      ? trimmed
      : `${trimmed}.md`;
    if (!trimmed || /[/\\:]/.test(name) || name.startsWith('.')) {
      setError('파일 이름을 입력하세요. 경로 구분자는 사용할 수 없습니다.');
      return;
    }
    run(async () => {
      await cloudFiles.writeText(name, editor.text, editor.create);
      setEditor(null);
      setMessage('파일 저장 완료. iCloud 업로드는 시스템이 처리합니다.');
      await reload();
    });
  };

  const open = (file: CloudFile) => {
    run(async () => {
      if (file.kind === 'markdown') {
        const text = await cloudFiles.readText(file.name);
        setPreview(null);
        setEditor({ name: file.name, text, create: false });
      } else {
        const uri = await cloudFiles.imageURI(file.name);
        setEditor(null);
        setPreview({ name: file.name, uri });
      }
    });
  };

  const removeImage = () => {
    if (!preview) {
      return;
    }
    const name = preview.name;
    Alert.alert('이미지 삭제', 'iCloud에서도 이 파일을 삭제합니다.', [
      { text: '취소', style: 'cancel' },
      {
        text: '삭제',
        style: 'destructive',
        onPress: () => {
          run(async () => {
            await cloudFiles.deleteImage(name);
            setPreview(null);
            setMessage('이미지 삭제 완료. iCloud 반영은 시스템이 처리합니다.');
            await reload();
          });
        },
      },
    ]);
  };

  return (
    <View style={styles.screen}>
      <ScrollView
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        <Text style={styles.heading}>iCloud 파일 PoC · macOS</Text>
        <Text>
          {connected ? 'iCloud Drive 연결됨' : 'iCloud Drive 연결 확인 필요'}
        </Text>
        <Text>사진과 마크다운 파일의 저장·관리를 검증합니다.</Text>
        <Button
          title="목록 새로고침"
          disabled={busy}
          onPress={() => run(reload)}
        />
        {busy && (
          <View accessibilityLabel="파일 작업 중">
            <ActivityIndicator />
            <Text>
              파일 작업 중… iCloud 다운로드는 시간이 걸릴 수 있습니다.
            </Text>
          </View>
        )}
        {!!error && (
          <Text accessibilityRole="alert" style={styles.error}>
            {error}
          </Text>
        )}
        {!!message && <Text accessibilityRole="alert">{message}</Text>}
        <Text style={styles.section}>마크다운</Text>
        <Button
          title="마크다운 생성"
          disabled={busy || !connected}
          onPress={() => {
            setPreview(null);
            setEditor({ name: '', text: '', create: true });
            setError('');
          }}
        />
        {files
          .filter(file => file.kind === 'markdown')
          .map(file => (
            <View key={file.name} style={styles.row}>
              <Button
                title={file.name}
                disabled={busy}
                onPress={() => open(file)}
              />
              <Text>{file.status}</Text>
            </View>
          ))}
        {connected && !files.some(file => file.kind === 'markdown') && (
          <Text>마크다운 파일이 없습니다.</Text>
        )}
        {editor && (
          <View style={styles.form}>
            <Text>
              {editor.create ? '새 마크다운 파일' : '단순 텍스트 편집'}
            </Text>
            <TextInput
              accessibilityLabel="마크다운 파일 이름"
              placeholder="파일 이름 (.md)"
              value={editor.name}
              editable={editor.create && !busy}
              autoCapitalize="none"
              autoCorrect={false}
              style={styles.input}
              onChangeText={name => setEditor({ ...editor, name })}
            />
            <TextInput
              accessibilityLabel="마크다운 원문"
              placeholder="마크다운 원문을 입력하세요"
              value={editor.text}
              editable={!busy}
              multiline
              textAlignVertical="top"
              autoCorrect={false}
              style={[styles.input, styles.editor]}
              onChangeText={text => setEditor({ ...editor, text })}
            />
            <Button title="저장" disabled={busy} onPress={save} />
            <Button
              title="편집 닫기"
              disabled={busy}
              onPress={() => setEditor(null)}
            />
          </View>
        )}
        <Text style={styles.section}>이미지</Text>
        <Button
          title="이미지 파일 등록"
          disabled={busy || !connected}
          onPress={() =>
            run(async () => {
              const name = await cloudFiles.importImage();
              if (name) {
                setMessage(
                  '사진 저장 완료. iCloud 업로드는 시스템이 처리합니다.',
                );
                await reload();
              }
            })
          }
        />
        {files
          .filter(file => file.kind === 'image')
          .map(file => (
            <View key={file.name} style={styles.row}>
              <Button
                title={file.name}
                disabled={busy}
                onPress={() => open(file)}
              />
              <Text>{file.status}</Text>
            </View>
          ))}
        {connected && !files.some(file => file.kind === 'image') && (
          <Text>이미지 파일이 없습니다.</Text>
        )}
        {preview && (
          <View style={styles.form}>
            <Text>{preview.name}</Text>
            <Image
              accessibilityLabel="저장된 이미지"
              source={{ uri: preview.uri }}
              resizeMode="contain"
              style={styles.image}
              onError={() =>
                setError('이미지를 표시할 수 없습니다. 다시 열어 주세요.')
              }
            />
            <Button title="이미지 삭제" disabled={busy} onPress={removeImage} />
            <Button
              title="이미지 닫기"
              disabled={busy}
              onPress={() => setPreview(null)}
            />
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: 'white' },
  content: { padding: 16, gap: 12 },
  heading: { fontSize: 24, fontWeight: '600', color: 'black' },
  section: { fontSize: 20, fontWeight: '600', marginTop: 12, color: 'black' },
  row: {
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderColor: '#ccc',
    paddingBottom: 8,
  },
  form: { gap: 8 },
  input: { borderWidth: 1, borderColor: '#888', padding: 10, color: 'black' },
  editor: { minHeight: 180 },
  image: { width: '100%', height: 300 },
  error: { color: '#b00020' },
});
