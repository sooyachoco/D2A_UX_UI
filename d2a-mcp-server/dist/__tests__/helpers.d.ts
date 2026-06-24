/** 임시 디렉토리를 생성하고 정리 함수를 반환한다. */
export declare function createTempDir(): {
    dir: string;
    cleanup: () => void;
};
/** git 저장소가 초기화된 임시 디렉토리를 생성한다. */
export declare function createTempGitRepo(): {
    dir: string;
    cleanup: () => void;
};
/** process.cwd()를 지정된 디렉토리로 모킹한다. */
export declare function mockCwd(dir: string): import("vitest").MockInstance<() => string>;
//# sourceMappingURL=helpers.d.ts.map