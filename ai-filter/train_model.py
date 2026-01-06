"""
Toxic Comment Classification Model Training Script
===================================================
Đồ án DACS4 - Study P2P Application
Sử dụng Machine Learning để phân loại bình luận thô tục

Thuật toán: TF-IDF Vectorization + Multiple Classifiers
- Naive Bayes (MultinomialNB)
- Logistic Regression
- Support Vector Machine (SVM)
- Random Forest

Author: Study P2P Team
"""

import os
import pandas as pd
import numpy as np
import pickle
import json
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.linear_model import LogisticRegression
from sklearn.svm import LinearSVC
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.pipeline import Pipeline
import warnings
warnings.filterwarnings('ignore')

# Đường dẫn
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(BASE_DIR, 'data', 'toxic_dataset.csv')
MODEL_DIR = os.path.join(BASE_DIR, 'models')

# Tạo thư mục models nếu chưa có
os.makedirs(MODEL_DIR, exist_ok=True)


def preprocess_text(text):
    """
    Tiền xử lý văn bản:
    - Chuyển thành chữ thường
    - Loại bỏ ký tự đặc biệt (giữ lại dấu tiếng Việt)
    """
    if pd.isna(text):
        return ""
    text = str(text).lower().strip()
    # Giữ lại chữ cái, số, khoảng trắng và dấu tiếng Việt
    return text


def load_data():
    """Load và tiền xử lý dữ liệu từ CSV"""
    print("📂 Loading dataset...")
    df = pd.read_csv(DATA_PATH)
    
    # Tiền xử lý
    df['text'] = df['text'].apply(preprocess_text)
    
    # Loại bỏ dòng trống
    df = df[df['text'].str.len() > 0]
    
    print(f"   ✅ Loaded {len(df)} samples")
    print(f"   📊 Class distribution:")
    print(f"      - Non-toxic (0): {len(df[df['label'] == 0])}")
    print(f"      - Toxic (1): {len(df[df['label'] == 1])}")
    
    return df


def create_pipelines():
    """
    Tạo các pipeline cho từng thuật toán ML
    Pipeline = TF-IDF Vectorizer + Classifier
    """
    
    # TF-IDF parameters
    tfidf_params = {
        'max_features': 5000,      # Số features tối đa
        'ngram_range': (1, 2),     # Unigrams và Bigrams
        'min_df': 1,               # Minimum document frequency
        'max_df': 0.95,            # Maximum document frequency
        'sublinear_tf': True,      # Áp dụng sublinear tf scaling
    }
    
    pipelines = {
        'naive_bayes': Pipeline([
            ('tfidf', TfidfVectorizer(**tfidf_params)),
            ('clf', MultinomialNB(alpha=0.1))
        ]),
        
        'logistic_regression': Pipeline([
            ('tfidf', TfidfVectorizer(**tfidf_params)),
            ('clf', LogisticRegression(
                C=1.0,
                max_iter=1000,
                random_state=42,
                class_weight='balanced'
            ))
        ]),
        
        'svm': Pipeline([
            ('tfidf', TfidfVectorizer(**tfidf_params)),
            ('clf', LinearSVC(
                C=1.0,
                max_iter=1000,
                random_state=42,
                class_weight='balanced'
            ))
        ]),
        
        'random_forest': Pipeline([
            ('tfidf', TfidfVectorizer(**tfidf_params)),
            ('clf', RandomForestClassifier(
                n_estimators=100,
                max_depth=20,
                random_state=42,
                class_weight='balanced',
                n_jobs=-1
            ))
        ])
    }
    
    return pipelines


def train_and_evaluate(pipelines, X_train, X_test, y_train, y_test):
    """
    Train và đánh giá từng model
    Trả về model tốt nhất
    """
    results = {}
    best_model = None
    best_accuracy = 0
    best_name = ""
    
    print("\n" + "="*60)
    print("🚀 TRAINING MODELS")
    print("="*60)
    
    for name, pipeline in pipelines.items():
        print(f"\n📌 Training {name.upper()}...")
        
        # Train
        pipeline.fit(X_train, y_train)
        
        # Predict
        y_pred = pipeline.predict(X_test)
        
        # Metrics
        accuracy = accuracy_score(y_test, y_pred)
        
        # Cross-validation
        cv_scores = cross_val_score(pipeline, X_train, y_train, cv=5)
        
        results[name] = {
            'accuracy': accuracy,
            'cv_mean': cv_scores.mean(),
            'cv_std': cv_scores.std()
        }
        
        print(f"   Accuracy: {accuracy:.4f}")
        print(f"   Cross-val: {cv_scores.mean():.4f} (+/- {cv_scores.std()*2:.4f})")
        
        # Classification report
        print(f"\n   Classification Report:")
        report = classification_report(y_test, y_pred, target_names=['Non-toxic', 'Toxic'])
        for line in report.split('\n'):
            print(f"   {line}")
        
        # Update best model
        if accuracy > best_accuracy:
            best_accuracy = accuracy
            best_model = pipeline
            best_name = name
    
    print("\n" + "="*60)
    print(f"🏆 BEST MODEL: {best_name.upper()} with accuracy {best_accuracy:.4f}")
    print("="*60)
    
    return best_model, best_name, results


def save_model(model, name, results):
    """Lưu model và metadata"""
    
    # Lưu model
    model_path = os.path.join(MODEL_DIR, 'toxic_classifier.pkl')
    with open(model_path, 'wb') as f:
        pickle.dump(model, f)
    print(f"\n💾 Model saved to: {model_path}")
    
    # Lưu metadata
    metadata = {
        'model_name': name,
        'results': results,
        'labels': {0: 'non-toxic', 1: 'toxic'},
        'description': 'Toxic comment classifier for Vietnamese and English'
    }
    
    metadata_path = os.path.join(MODEL_DIR, 'model_metadata.json')
    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    print(f"📋 Metadata saved to: {metadata_path}")


def test_model(model):
    """Test model với một số câu mẫu"""
    
    print("\n" + "="*60)
    print("🧪 TESTING MODEL WITH SAMPLE SENTENCES")
    print("="*60)
    
    test_sentences = [
        # Non-toxic
        "Xin chào bạn, hôm nay bạn khỏe không?",
        "Cảm ơn bạn đã giúp đỡ",
        "Hello everyone, nice to meet you",
        "Great job on the project!",
        "Bài học hôm nay thật thú vị",
        
        # Toxic
        "Mày ngu vãi",
        "Đồ khốn nạn",
        "You are so stupid",
        "Shut up idiot",
        "Cút đi đồ ngu",
        
        # Edge cases
        "Bạn học bài chưa?",
        "Bài này khó quá",
        "This is challenging",
        "Mày làm bài chưa?",  # Có từ "mày" nhưng không toxic
    ]
    
    predictions = model.predict(test_sentences)
    
    # Nếu model có predict_proba
    try:
        probabilities = model.predict_proba(test_sentences)
        has_proba = True
    except:
        has_proba = False
    
    for i, (sentence, pred) in enumerate(zip(test_sentences, predictions)):
        label = "🚫 TOXIC" if pred == 1 else "✅ OK"
        if has_proba:
            conf = probabilities[i][pred] * 100
            print(f"{label} ({conf:.1f}%): {sentence}")
        else:
            print(f"{label}: {sentence}")


def main():
    """Main training pipeline"""
    
    print("\n" + "="*60)
    print("🤖 TOXIC COMMENT CLASSIFIER - TRAINING")
    print("   Study P2P - DACS4 Project")
    print("="*60)
    
    # 1. Load data
    df = load_data()
    
    X = df['text'].values
    y = df['label'].values
    
    # 2. Split data
    print("\n📊 Splitting data (80% train, 20% test)...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, 
        test_size=0.2, 
        random_state=42,
        stratify=y
    )
    print(f"   Train: {len(X_train)} samples")
    print(f"   Test: {len(X_test)} samples")
    
    # 3. Create pipelines
    pipelines = create_pipelines()
    
    # 4. Train and evaluate
    best_model, best_name, results = train_and_evaluate(
        pipelines, X_train, X_test, y_train, y_test
    )
    
    # 5. Save model
    save_model(best_model, best_name, results)
    
    # 6. Test với câu mẫu
    test_model(best_model)
    
    print("\n" + "="*60)
    print("✅ TRAINING COMPLETED!")
    print("="*60)


if __name__ == "__main__":
    main()
