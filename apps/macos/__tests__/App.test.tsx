import React from 'react';
import { Alert, AppState, Button, Image, TextInput } from 'react-native';
import Renderer, { act, type ReactTestRenderer } from 'react-test-renderer';
import App from '../App';
import { cloudFiles, type CloudFile } from '../src/cloudFiles';

jest.mock('../src/cloudFiles', () => ({
  cloudFiles: {
    getState: jest.fn(),
    listFiles: jest.fn(),
    readText: jest.fn(),
    writeText: jest.fn(),
    importImage: jest.fn(),
    imageURI: jest.fn(),
    deleteImage: jest.fn(),
  },
}));

const api = jest.mocked(cloudFiles);
let app: ReactTestRenderer;
const markdown: CloudFile = {
  name: 'note.md',
  kind: 'markdown',
  status: '업로드됨',
};
const image: CloudFile = {
  name: 'photo.jpg',
  kind: 'image',
  status: '업로드됨',
};
const button = (title: string) =>
  app.root.findAllByType(Button).find(node => node.props.title === title)!;
const input = (label: string) =>
  app.root
    .findAllByType(TextInput)
    .find(node => node.props.accessibilityLabel === label)!;
const click = async (title: string) => {
  await act(async () => button(title).props.onPress());
};
const change = async (label: string, value: string) => {
  await act(async () => input(label).props.onChangeText(value));
};
const rendered = () => JSON.stringify(app.toJSON());

beforeEach(async () => {
  jest.resetAllMocks();
  jest
    .spyOn(AppState, 'addEventListener')
    .mockReturnValue({ remove: jest.fn() });
  api.getState.mockResolvedValue({
    available: true,
    directory: '/iCloud/Documents',
  });
  api.listFiles.mockResolvedValue([markdown, image]);
  api.writeText.mockResolvedValue(undefined);
  api.deleteImage.mockResolvedValue(undefined);
  await act(async () => {
    app = Renderer.create(<App />);
  });
});
afterEach(async () => {
  await act(async () => app.unmount());
});

test('lists markdown and image files from the cloud API', () => {
  expect(button('note.md')).toBeDefined();
  expect(button('photo.jpg')).toBeDefined();
  expect(rendered()).toContain('iCloud Drive 연결됨');
});

test('creates a markdown file and saves the plain text unchanged', async () => {
  await click('마크다운 생성');
  await change('마크다운 파일 이름', 'new-note');
  await change('마크다운 원문', '# 제목\n**그대로 저장**');
  await click('저장');
  expect(api.writeText).toHaveBeenCalledWith(
    'new-note.md',
    '# 제목\n**그대로 저장**',
    true,
  );
  expect(api.listFiles).toHaveBeenCalledTimes(2);
});

test('opens an existing document and persists plain text edits', async () => {
  api.readText.mockResolvedValue('# original');
  await click('note.md');
  expect(input('마크다운 원문').props.value).toBe('# original');
  expect(input('마크다운 파일 이름').props.editable).toBe(false);
  await change('마크다운 원문', '편집한 텍스트');
  await click('저장');
  expect(api.writeText).toHaveBeenCalledWith('note.md', '편집한 텍스트', false);
});

test('preserves unsaved text when saving fails', async () => {
  api.writeText.mockRejectedValue(new Error('저장 실패'));
  await click('마크다운 생성');
  await change('마크다운 파일 이름', 'draft.md');
  await change('마크다운 원문', '보존할 내용');
  await click('저장');
  expect(input('마크다운 원문').props.value).toBe('보존할 내용');
  expect(rendered()).toContain('저장 실패');
});

test('imports an image, previews its cloud copy and deletes after confirmation', async () => {
  api.importImage.mockResolvedValue('photo.jpg');
  await click('이미지 파일 등록');
  expect(api.importImage).toHaveBeenCalledTimes(1);
  expect(api.listFiles).toHaveBeenCalledTimes(2);
  api.imageURI.mockResolvedValue('file:///cache/photo.jpg');
  await click('photo.jpg');
  expect(app.root.findByType(Image).props.source.uri).toBe(
    'file:///cache/photo.jpg',
  );
  const alert = jest.spyOn(Alert, 'alert');
  await click('이미지 삭제');
  expect(api.deleteImage).not.toHaveBeenCalled();
  const confirm = alert.mock.calls[0][2]!.find(
    action => action.text === '삭제',
  )!;
  await act(async () => confirm.onPress!());
  expect(api.deleteImage).toHaveBeenCalledWith('photo.jpg');
  expect(app.root.findAllByType(Image)).toHaveLength(0);
  alert.mockRestore();
});

test('cancelling the photo picker does not refresh or create a file', async () => {
  api.importImage.mockResolvedValue(null);
  await click('이미지 파일 등록');
  expect(api.listFiles).toHaveBeenCalledTimes(1);
  expect(api.writeText).not.toHaveBeenCalled();
});

test('shows cloud errors and clears the file list instead of using local storage', async () => {
  api.getState.mockRejectedValue(new Error('iCloud 연결 불가'));
  await click('목록 새로고침');
  expect(rendered()).toContain('iCloud 연결 불가');
  expect(button('마크다운 생성').props.disabled).toBe(true);
  expect(button('note.md')).toBeUndefined();
});
