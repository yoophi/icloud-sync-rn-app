import { NativeModules } from 'react-native';

export type CloudFile = {
  name: string;
  kind: 'markdown' | 'image';
  status: string;
};

type CloudFiles = {
  getState(): Promise<{ available: boolean; directory: string }>;
  listFiles(): Promise<CloudFile[]>;
  readText(name: string): Promise<string>;
  writeText(name: string, text: string, create: boolean): Promise<void>;
  importImage(): Promise<string | null>;
  imageURI(name: string): Promise<string>;
  deleteImage(name: string): Promise<void>;
};

function native(): CloudFiles {
  const module = NativeModules.ICloudFiles as CloudFiles | undefined;
  if (!module) {
    throw new Error(
      'iPhone 앱을 다시 빌드하세요. iCloud 파일 모듈을 찾을 수 없습니다.',
    );
  }
  return module;
}

export const cloudFiles: CloudFiles = {
  getState: async () => native().getState(),
  listFiles: async () => native().listFiles(),
  readText: async name => native().readText(name),
  writeText: async (name, text, create) =>
    native().writeText(name, text, create),
  importImage: async () => native().importImage(),
  imageURI: async name => native().imageURI(name),
  deleteImage: async name => native().deleteImage(name),
};
