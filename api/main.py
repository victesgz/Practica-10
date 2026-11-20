import os
import shutil
import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import Depends, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Integer, String, create_engine, text
from sqlalchemy.orm import Session, declarative_base, sessionmaker

DATABASE_URL = "mysql+pymysql://root:@localhost:3306/practica_fotos"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Foto(Base):
    __tablename__ = "P10_foto"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    descripcion = Column(String(255), nullable=False)
    ruta_foto = Column(String(255), nullable=False)
    fecha = Column(DateTime, server_default=text("CURRENT_TIMESTAMP"), nullable=True)


Base.metadata.create_all(bind=engine)


class FotoResponse(BaseModel):
    id: int
    descripcion: str
    ruta_foto: str
    fecha: Optional[datetime] = None

    class Config:
        from_attributes = True


UPLOAD_DIR = "fotos_subidas"
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_MIME_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}

app = FastAPI(title="API Gestión de Fotos - P10_foto")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/fotos_subidas", StaticFiles(directory=UPLOAD_DIR), name="fotos_subidas")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.post("/fotos", response_model=FotoResponse)
async def crear_foto(
    request: Request,
    descripcion: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo de archivo no permitido: {file.content_type}",
        )

    extension = ALLOWED_MIME_TYPES[file.content_type]
    nombre_archivo = f"{uuid.uuid4().hex}{extension}"
    ruta_fisica = os.path.join(UPLOAD_DIR, nombre_archivo)

    with open(ruta_fisica, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    base_url = str(request.base_url).rstrip("/")
    url_publica = f"{base_url}/fotos_subidas/{nombre_archivo}"

    registro = Foto(
        descripcion=descripcion,
        ruta_foto=url_publica,
    )
    db.add(registro)
    db.commit()
    db.refresh(registro)
    return registro


@app.get("/fotos", response_model=List[FotoResponse])
def obtener_fotos(db: Session = Depends(get_db)):
    return db.query(Foto).order_by(Foto.id.desc()).all()