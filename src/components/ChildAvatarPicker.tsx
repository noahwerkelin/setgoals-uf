import { useRef, useState } from "react";
import { Camera, Trash2 } from "lucide-react";
import { isImageAvatar } from "@/lib/settings";
import { useT } from "@/lib/i18n";

export const CHILD_EMOJIS = ["🌱", "🐻", "🦊", "🐼", "🦁", "🐸", "🦄", "⭐️", "🚀"];

export function ChildAvatar({ avatar, name, className = "" }: { avatar: string | null; name?: string; className?: string }) {
  if (isImageAvatar(avatar)) {
    return (
      <span className={`grid place-items-center overflow-hidden rounded-full bg-sage-200 ${className}`}>
        <img src={avatar!} alt={name ?? ""} className="size-full object-cover" />
      </span>
    );
  }
  return <span className={`grid place-items-center rounded-full bg-sage-200 ${className}`}>{avatar || "🌱"}</span>;
}

export { fileToSquareDataUrl };


export function ChildAvatarPicker({
  value,
  onChange,
}: {
  value: string | null;
  onChange: (v: string) => void;
}) {
  const { t } = useT();
  const fileRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const hasPhoto = isImageAvatar(value);

  const pick = async (file?: File | null) => {
    if (!file) return;
    setBusy(true);
    try {
      onChange(await fileToSquareDataUrl(file));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="rounded-3xl bg-sage-50 p-4 ring-1 ring-black/5">
      <div className="flex items-center gap-4">
        <button
          type="button"
          onClick={() => fileRef.current?.click()}
          className="relative grid size-20 shrink-0 place-items-center overflow-hidden rounded-full bg-sage-200 text-3xl ring-2 ring-sage-600/30"
          aria-label={t("parent.child.upload_photo")}
        >
          {hasPhoto ? (
            <img src={value!} alt="" className="size-full object-cover" />
          ) : (
            <span>{value || "🌱"}</span>
          )}
          <span className="absolute inset-x-0 bottom-0 grid h-6 place-items-center bg-black/45 text-white">
            <Camera className="size-3.5" />
          </span>
        </button>

        <div className="min-w-0 flex-1 space-y-2">
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            disabled={busy}
            className="w-full rounded-2xl bg-sage-600 px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
          >
            {busy ? t("parent.child.uploading") : t("parent.child.upload_photo")}
          </button>
          {hasPhoto && (
            <button
              type="button"
              onClick={() => onChange(CHILD_EMOJIS[0])}
              className="flex w-full items-center justify-center gap-1.5 rounded-2xl bg-card px-4 py-2 text-xs font-medium text-destructive ring-1 ring-black/5"
            >
              <Trash2 className="size-3.5" />
              {t("parent.child.remove_photo")}
            </button>
          )}
        </div>
      </div>

      <p className="mt-4 mb-2 text-[11px] font-medium uppercase tracking-wider text-sage-600">
        {t("parent.child.or_emoji")}
      </p>
      <div className="flex flex-wrap gap-2">
        {CHILD_EMOJIS.map((a) => (
          <button
            key={a}
            type="button"
            onClick={() => onChange(a)}
            className={`grid h-10 w-10 place-items-center rounded-xl text-xl ring-1 transition-colors ${
              value === a ? "bg-sage-600 ring-sage-700" : "bg-card ring-black/5"
            }`}
          >
            {a}
          </button>
        ))}
      </div>

      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          void pick(e.target.files?.[0]);
          e.target.value = "";
        }}
      />
    </div>
  );
}
